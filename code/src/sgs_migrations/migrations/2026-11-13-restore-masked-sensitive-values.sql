-- Restore the default of a sensitive variable, and the value of a tfvar, that is stored as the
-- string '__SENSITIVE__'.  The value comes from the newest committed transaction log row that
-- wrote the same block or tfvar with a different value.  A row with no such log row stays as it
-- is.  The guard on '__SENSITIVE__' makes the migration idempotent.
UPDATE hcl
SET data = sub.data
FROM (
    SELECT DISTINCT ON (h.state_id, h.id)
        h.state_id,
        h.id,
        txl.data -> 'data' AS data
    FROM hcl h
    JOIN transaction_logs txl ON txl.state_id = h.state_id
    JOIN transactions t ON t.id = txl.tx_id
    WHERE h.data -> 0 ->> 'type' = 'variable'
      AND h.data -> 0 -> 'attrs' @> '[{"sensitive": true}]'
      AND h.data -> 0 -> 'attrs' @> '[{"default": "__SENSITIVE__"}]'
      AND t.state = 'committed'
      AND txl.action = 'hcl_set'
      AND txl.data -> 'tf_module' IS NULL
      AND txl.data ->> 'node_id' = h.id
      AND NOT txl.data -> 'data' -> 0 -> 'attrs' @> '[{"default": "__SENSITIVE__"}]'
    ORDER BY h.state_id, h.id, txl.created_at DESC, txl.id DESC
) sub
WHERE hcl.state_id = sub.state_id
  AND hcl.id = sub.id;

UPDATE tf_module_hcl
SET data = sub.data
FROM (
    SELECT DISTINCT ON (b.state_id, b.source, b.version, b.id)
        b.state_id,
        b.source,
        b.version,
        b.id,
        txl.data -> 'data' AS data
    FROM tf_module_hcl b
    JOIN transaction_logs txl ON txl.state_id = b.state_id
    JOIN transactions t ON t.id = txl.tx_id
    WHERE b.data -> 0 ->> 'type' = 'variable'
      AND b.data -> 0 -> 'attrs' @> '[{"sensitive": true}]'
      AND b.data -> 0 -> 'attrs' @> '[{"default": "__SENSITIVE__"}]'
      AND t.state = 'committed'
      AND txl.action = 'hcl_set'
      AND txl.data -> 'tf_module' ->> 'source' = b.source
      AND coalesce(txl.data -> 'tf_module' ->> 'version', '') = b.version
      AND txl.data ->> 'body_id' = b.id
      AND NOT txl.data -> 'data' -> 0 -> 'attrs' @> '[{"default": "__SENSITIVE__"}]'
    ORDER BY b.state_id, b.source, b.version, b.id, txl.created_at DESC, txl.id DESC
) sub
WHERE tf_module_hcl.state_id = sub.state_id
  AND tf_module_hcl.source = sub.source
  AND tf_module_hcl.version = sub.version
  AND tf_module_hcl.id = sub.id;

UPDATE tfvars
SET data = sub.data
FROM (
    SELECT DISTINCT ON (tv.state_id, tv.var_address)
        tv.state_id,
        tv.var_address,
        txl.data -> 'data' AS data
    FROM tfvars tv
    JOIN transaction_logs txl ON txl.state_id = tv.state_id
    JOIN transactions t ON t.id = txl.tx_id
    WHERE tv.data = '"__SENSITIVE__"'::jsonb
      AND t.state = 'committed'
      AND txl.action = 'tfvar_set'
      AND txl.data ->> 'var_address' = tv.var_address
      AND txl.data -> 'data' <> '"__SENSITIVE__"'::jsonb
    ORDER BY tv.state_id, tv.var_address, txl.created_at DESC, txl.id DESC
) sub
WHERE tfvars.state_id = sub.state_id
  AND tfvars.var_address = sub.var_address;
