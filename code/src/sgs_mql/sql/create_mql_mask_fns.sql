-- Ephemeral helper functions for the MQL endpoint's sensitive-value masking.
-- [unwrap_dynamic_value], [walk_attrs], [sensitive_attr_path] and
-- [mask_sensitive_attributes] each have an OCaml twin in [Sg_tf_state.Inline]
-- — keep those in lockstep so SQL and OCaml mask the same values.
--
-- Defined in [pg_temp] so they live for the duration of the calling backend
-- session and are dropped automatically by PostgreSQL when the pooled
-- connection closes.

-- Recursively unwrap [{"type":..., "value":...}] DynamicValue envelopes that
-- Terraform uses for terraform_data and similar attributes.  Mirror of
-- [Sg_tf_state.Inline.unwrap_dynamic_value].
create or replace function pg_temp.unwrap_dynamic_value(j jsonb)
returns jsonb
language sql
immutable
as $$
    select case
        when jsonb_typeof(j) = 'object'
             and (j ? 'type') and (j ? 'value')
             and (select count(*) from jsonb_object_keys(j)) = 2
        then pg_temp.unwrap_dynamic_value(j -> 'value')
        else j
    end
$$;

-- Walk [attr_path] through [attributes].  Each step unwraps any
-- DynamicValue envelope.  Returns NULL for any missing or JSON-null
-- segment.  Mirror of [Sg_tf_state.Inline.walk_attrs].
create or replace function pg_temp.walk_attrs(attributes jsonb, attr_path text[])
returns jsonb
language plpgsql
immutable
as $$
declare
    cur jsonb := pg_temp.unwrap_dynamic_value(attributes);
    seg text;
    next jsonb;
begin
    if attr_path is null or array_length(attr_path, 1) is null then
        return cur;
    end if;
    foreach seg in array attr_path loop
        if cur is null or jsonb_typeof(cur) <> 'object' then
            return null;
        end if;
        next := cur -> seg;
        if next is null or jsonb_typeof(next) = 'null' then
            return null;
        end if;
        cur := pg_temp.unwrap_dynamic_value(next);
    end loop;
    return cur;
end
$$;

-- Extract the leading run of [get_attr] string steps from a single
-- sensitive_attributes entry into a path.  Returns NULL to signal "treat the
-- whole instance as sensitive" — the entry is not an array, or a step is not a
-- typed object.  A non-get_attr step (e.g. an index) terminates the run, so the
-- accumulated prefix is returned (possibly the empty array, which overlaps every
-- path).  Mirror of [Sg_tf_state.Inline.sensitive_attr_path].
create or replace function pg_temp.sensitive_attr_path(entry jsonb)
returns text[]
language plpgsql
immutable
as $$
declare
    step jsonb;
    sens_path text[] := array[]::text[];
begin
    if jsonb_typeof(entry) <> 'array' then
        return null;
    end if;
    for step in select * from jsonb_array_elements(entry) loop
        if jsonb_typeof(step) <> 'object' or (step ->> 'type') is null then
            return null;
        end if;
        if (step ->> 'type') = 'get_attr' and (step ->> 'value') is not null then
            sens_path := sens_path || (step ->> 'value');
        else
            exit;
        end if;
    end loop;
    return sens_path;
end
$$;


-- Return [attributes] with every value declared sensitive in
-- [sensitive_attributes] replaced by the JSON string sentinel
-- '__SENSITIVE__'.  Used by the MQL endpoint to mask secrets before they leave
-- the database.  Sensitivity is decided with the same prefix-overlap semantics
-- as [Sg_tf_state.Inline.attr_path_is_sensitive]: an entry's leading get_attr
-- run names the path whose subtree is redacted.  Conservative — any entry we cannot resolve
-- to a concrete present path masks the whole blob rather than risk leaking.
-- Mirror of [Sg_tf_state.Inline.mask_attributes].
create or replace function pg_temp.mask_sensitive_attributes(
    attributes jsonb,
    sensitive_attributes jsonb)
returns jsonb
language plpgsql
immutable
as $$
declare
    result jsonb := attributes;
    entry jsonb;
    sens_path text[];
begin
    if attributes is null or jsonb_typeof(attributes) = 'null' then
        return attributes;
    end if;
    if sensitive_attributes is null or jsonb_typeof(sensitive_attributes) = 'null' then
        return attributes;
    end if;
    -- A non-array marks the whole instance sensitive (mirror of
    -- attr_path_is_sensitive returning TRUE).
    if jsonb_typeof(sensitive_attributes) <> 'array' then
        return to_jsonb('__SENSITIVE__'::text);
    end if;
    for entry in select * from jsonb_array_elements(sensitive_attributes) loop
        sens_path := pg_temp.sensitive_attr_path(entry);
        -- NULL (unparseable) or empty path (overlaps everything) => whole blob.
        if sens_path is null or coalesce(array_length(sens_path, 1), 0) = 0 then
            return to_jsonb('__SENSITIVE__'::text);
        end if;
        if (result #> sens_path) is not null and jsonb_typeof(result #> sens_path) <> 'null' then
            result := jsonb_set(result, sens_path, to_jsonb('__SENSITIVE__'::text), false);
        elsif pg_temp.walk_attrs(result, sens_path) is not null then
            -- The path resolves only after unwrapping a DynamicValue envelope,
            -- which [#>]/[jsonb_set] cannot navigate.  Mask the whole blob.
            return to_jsonb('__SENSITIVE__'::text);
        end if;
    end loop;
    return result;
end
$$;

-- Mask the secret-bearing payload of a transaction_logs [data] row in place,
-- keyed on its object_type.  Instance rows carry [attributes] +
-- [sensitive_attributes]; output rows carry [value] gated by [sensitive].  All
-- other object types pass through untouched.  Used by the MQL endpoint.
create or replace function pg_temp.mask_tx_log_data(object_type text, data jsonb)
returns jsonb
language plpgsql
immutable
as $$
begin
    if data is null or jsonb_typeof(data) <> 'object' then
        return data;
    end if;
    if object_type = 'instance' then
        if data ? 'attributes' then
            return jsonb_set(
                data,
                '{attributes}',
                pg_temp.mask_sensitive_attributes(data -> 'attributes', data -> 'sensitive_attributes'),
                false);
        end if;
        return data;
    elsif object_type = 'output' then
        if coalesce((data ->> 'sensitive')::boolean, false) and (data ? 'value') then
            return jsonb_set(data, '{value}', to_jsonb('__SENSITIVE__'::text), false);
        end if;
        return data;
    end if;
    return data;
end
$$;

-- Mask the value of an ephemeral tfvar's transaction_logs [data] row (RFD 1377).
--
-- Keyed on the ACTION rather than the object_type, unlike mask_tx_log_data:
-- an ephemeral tfvar is stored with object_type 'tfvar', identical to an
-- ordinary one, and only the action tells them apart.  Masking by object_type
-- would blank every tfvar's value, including the non-ephemeral ones a reader
-- legitimately needs.
--
-- Only [data] is replaced.  [node_id] and [var_address] survive so a masked row
-- stays identifiable BY NAME -- a reader must be able to tell a masked row from
-- a row that was silently dropped.  The transaction log entry is the only
-- surviving copy of the value (an ephemeral tfvar is never committed to the
-- [tfvars] table), so this is the one place it can leak.
create or replace function pg_temp.mask_tfvar_ephemeral_data(data jsonb)
returns jsonb
language plpgsql
immutable
as $$
begin
    if data is null or jsonb_typeof(data) <> 'object' then
        return data;
    end if;
    if data ? 'data' then
        return jsonb_set(data, '{data}', to_jsonb('__SENSITIVE__'::text), false);
    end if;
    return data;
end
$$;
