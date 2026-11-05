/**
 * Minimal JSON-value to YAML serializer for displaying a repository
 * configuration the way its author wrote it. The stored config is decoded
 * JSON, but the file on disk is YAML, so rendering YAML is what a reader
 * recognizes. The output is copyable, so it must parse back to the same value.
 */

type Json = null | boolean | number | string | Json[] | { [k: string]: Json };

// Plain scalars are safe unquoted only when they cannot be read as another
// YAML type (bool/null/number) and carry no indicator characters.
const PLAIN = /^[A-Za-z0-9_][A-Za-z0-9_./@+-]*$/;
const RESERVED = /^(true|false|null|yes|no|on|off|y|n|~)$/i;

/** A scalar value or mapping key. Anything not safely plain is emitted as a
 *  JSON string, which is valid YAML double-quoted syntax and escapes newlines
 *  and control characters. */
function scalar(v: null | boolean | number | string): string {
  if (v === null) return "null";
  if (typeof v === "boolean" || typeof v === "number") return String(v);
  if (PLAIN.test(v) && !RESERVED.test(v) && !/^-?\d/.test(v)) return v;
  return JSON.stringify(v);
}

const isObj = (v: Json): v is { [k: string]: Json } =>
  v !== null && typeof v === "object" && !Array.isArray(v);
const isEmpty = (v: Json): boolean =>
  (Array.isArray(v) && v.length === 0) || (isObj(v) && Object.keys(v).length === 0);

/** One `key: value` line, prefixed by `lead`; a non-empty collection value
 *  continues on the following lines at `indent`. */
function entry(lead: string, k: string, v: Json, indent: number, out: string[]): void {
  const key = scalar(k);
  if (isEmpty(v)) out.push(`${lead}${key}: ${Array.isArray(v) ? "[]" : "{}"}`);
  else if (isObj(v) || Array.isArray(v)) {
    out.push(`${lead}${key}:`);
    emit(v, indent, out);
  } else out.push(`${lead}${key}: ${scalar(v)}`);
}

function emit(value: Json, indent: number, out: string[]): void {
  const pad = "  ".repeat(indent);
  if (Array.isArray(value)) {
    for (const item of value) {
      if (isObj(item) && !isEmpty(item)) {
        Object.keys(item).forEach((k, i) =>
          entry(i === 0 ? `${pad}- ` : `${pad}  `, k, item[k], indent + 2, out),
        );
      } else if (isEmpty(item)) {
        out.push(`${pad}- ${Array.isArray(item) ? "[]" : "{}"}`);
      } else if (Array.isArray(item)) {
        out.push(`${pad}-`);
        emit(item, indent + 1, out);
      } else {
        out.push(`${pad}- ${scalar(item as never)}`);
      }
    }
    return;
  }
  if (isObj(value)) {
    for (const k of Object.keys(value)) entry(pad, k, value[k], indent + 1, out);
    return;
  }
  out.push(`${pad}${scalar(value as never)}`);
}

export function toYaml(value: unknown): string {
  const out: string[] = [];
  emit((value ?? {}) as Json, 0, out);
  return out.join("\n");
}
