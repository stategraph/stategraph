/**
 * Query Autocomplete Engine
 *
 * Provides context-aware suggestions for MQL keywords, tables, fields, and values.
 */

import { getTableNames, getTableColumns, type MQLTable } from '@/lib/query/mqlSchema';

export interface Suggestion {
  text: string;
  type: 'keyword' | 'field' | 'value' | 'operator' | 'table';
  description?: string;
}

export interface AutocompleteContext {
  query: string;
  cursorPosition: number;
  providers: string[];
  types: string[];
  schema: MQLTable[];
}

const SQL_KEYWORDS = ['select', 'from', 'where', 'and', 'or', 'in', 'like', 'join', 'left join', 'inner join', 'on', 'group by', 'order by', 'limit', 'count'];
const FALLBACK_FIELDS = ['address', 'type', 'provider', 'module', 'name', 'status', 'state_id'];
const OPERATORS = ['=', '!=', 'like', 'in', '<', '>', '<=', '>='];

/**
 * Get autocomplete suggestions based on current context
 */
export function getAutocompleteSuggestions(context: AutocompleteContext): Suggestion[] {
  const { query, cursorPosition, providers, types, schema } = context;

  // Get the word being typed at cursor position
  const { word, wordStart: _wordStart } = getCurrentWord(query, cursorPosition);

  // Determine context: are we in SELECT, FROM, WHERE clause?
  const sqlContext = getSQLContext(query, cursorPosition);

  // For table suggestions after FROM, always show all tables (even with empty word)
  // For other contexts, need at least 1 character to show suggestions
  if (word.length < 1 && sqlContext !== 'from-table') {
    return [];
  }

  // Resolve columns from the FROM table in the schema
  const fromTable = getFromTable(query);
  const schemaColumns = fromTable
    ? getTableColumns(schema, fromTable).map(c => c.name)
    : [];
  const fieldList = schemaColumns.length > 0 ? schemaColumns : FALLBACK_FIELDS;

  // Get suggestions based on context
  let suggestions: Suggestion[] = [];

  switch (sqlContext) {
    case 'keyword':
      // Suggest SQL keywords
      suggestions = SQL_KEYWORDS
        .filter(kw => kw.toLowerCase().startsWith(word.toLowerCase()))
        .map(kw => ({ text: kw, type: 'keyword' as const }));
      break;

    case 'select-fields':
      // After SELECT, suggest fields or *
      if ('*'.startsWith(word)) {
        suggestions.push({ text: '*', type: 'field', description: 'All fields' });
      }
      suggestions.push(
        ...fieldList
          .filter(f => f.toLowerCase().startsWith(word.toLowerCase()))
          .map(f => ({ text: f, type: 'field' as const, description: fromTable ? `${fromTable}.${f}` : undefined }))
      );
      break;

    case 'from-table': {
      // After FROM, suggest all MQL tables (show all if word is empty)
      const tableNames = getTableNames(schema);
      suggestions = tableNames
        .filter(table => word.length === 0 || table.toLowerCase().startsWith(word.toLowerCase()))
        .map(table => ({
          text: table,
          type: 'table' as const,
          description: `${table} table`,
        }));
      break;
    }

    case 'where-field':
      // In WHERE clause, suggest fields from schema
      suggestions = fieldList
        .filter(f => f.toLowerCase().startsWith(word.toLowerCase()))
        .map(f => ({ text: f, type: 'field' as const, description: fromTable ? `${fromTable}.${f}` : undefined }));
      break;

    case 'where-operator':
      // After field name in WHERE, suggest operators
      suggestions = OPERATORS
        .filter(op => op.startsWith(word))
        .map(op => ({ text: op, type: 'operator' as const }));
      break;

    case 'where-value': {
      // After operator, suggest values based on field
      const field = getFieldBeforeCursor(query, cursorPosition);
      suggestions = getValueSuggestions(field, word, providers, types);
      break;
    }

    case 'logical-operator':
      // Suggest AND/OR
      ['AND', 'OR']
        .filter(op => op.toLowerCase().startsWith(word.toLowerCase()))
        .forEach(op => suggestions.push({ text: op, type: 'keyword' as const }));
      break;
  }

  return suggestions;
}

/**
 * Get the current word being typed at cursor position
 */
function getCurrentWord(text: string, cursorPos: number): { word: string; wordStart: number } {
  // Look backwards from cursor to find word start
  let wordStart = cursorPos;
  while (wordStart > 0 && /[a-zA-Z0-9_:]/.test(text[wordStart - 1])) {
    wordStart--;
  }

  // Look forwards from cursor to find word end
  let wordEnd = cursorPos;
  while (wordEnd < text.length && /[a-zA-Z0-9_:]/.test(text[wordEnd])) {
    wordEnd++;
  }

  const word = text.substring(wordStart, wordEnd);
  return { word, wordStart };
}

/**
 * Extract the table name from the FROM clause of a query
 */
function getFromTable(query: string): string | null {
  const match = query.match(/FROM\s+(\w+)/i);
  return match ? match[1] : null;
}

/**
 * Determine what SQL context we're in
 */
function getSQLContext(query: string, cursorPos: number): string {
  const beforeCursor = query.substring(0, cursorPos).toUpperCase();

  // Check if we're at the start or after a semicolon (new statement)
  if (/^\s*$/.test(beforeCursor) || /;\s*$/.test(beforeCursor)) {
    return 'keyword';
  }

  // Check for SELECT context
  if (/SELECT\s+$/i.test(beforeCursor)) {
    return 'select-fields';
  }

  // Check if we're in SELECT field list
  if (/SELECT\s+[^FROM]*$/i.test(beforeCursor) && !/FROM/i.test(beforeCursor)) {
    // If last character is comma or space after comma, suggest field
    if (/,\s*\w*$/.test(beforeCursor)) {
      return 'select-fields';
    }
    return 'select-fields';
  }

  // Check for FROM context
  if (/FROM\s+$/i.test(beforeCursor)) {
    return 'from-table';
  }

  // Check for WHERE context
  if (/WHERE\s+$/i.test(beforeCursor)) {
    return 'where-field';
  }

  // In WHERE clause, determine if we need field, operator, or value
  if (/WHERE/i.test(beforeCursor)) {
    const afterWhere = beforeCursor.substring(beforeCursor.lastIndexOf('WHERE'));

    // Check if we just finished typing a field name (followed by space)
    if (/WHERE\s+\w+\s+$/.test(afterWhere) || /AND\s+\w+\s+$/.test(afterWhere) || /OR\s+\w+\s+$/.test(afterWhere)) {
      return 'where-operator';
    }

    // Check if we're after an operator (= != LIKE IN)
    if (/(=|!=|LIKE|IN)\s*'?\w*$/.test(afterWhere)) {
      return 'where-value';
    }

    // Check if we might be typing a logical operator
    if (/\w+\s*(!?=|LIKE|IN)\s*'[^']*'\s*\w*$/.test(afterWhere)) {
      return 'logical-operator';
    }

    // Default to field in WHERE
    return 'where-field';
  }

  // Check if we might be starting a new keyword
  if (/\s+\w*$/.test(beforeCursor)) {
    return 'keyword';
  }

  return 'keyword';
}

/**
 * Get the field name that appears before the cursor in a WHERE clause
 */
function getFieldBeforeCursor(query: string, cursorPos: number): string | null {
  const beforeCursor = query.substring(0, cursorPos);

  // Look for pattern: field_name = 'value' or field_name LIKE 'value'
  const match = beforeCursor.match(/(\w+)\s*(!?=|LIKE|IN)\s*'?\w*$/i);
  if (match) {
    return match[1].toLowerCase();
  }

  return null;
}

/**
 * Get value suggestions based on the field being filtered
 */
function getValueSuggestions(
  field: string | null,
  partial: string,
  providers: string[],
  types: string[]
): Suggestion[] {
  if (!field) {
    return [];
  }

  // Remove quotes from partial input
  const cleanPartial = partial.replace(/^['"]|['"]$/g, '').toLowerCase();

  switch (field) {
    case 'provider':
      return providers
        .filter(p => p.toLowerCase().startsWith(cleanPartial))
        .map(p => ({ text: `'${p}'`, type: 'value' as const, description: `Provider: ${p}` }));

    case 'type':
      return types
        .filter(t => t.toLowerCase().startsWith(cleanPartial))
        .slice(0, 20) // Limit to top 20
        .map(t => ({ text: `'${t}'`, type: 'value' as const, description: `Type: ${t}` }));

    case 'module':
      // Could suggest common modules, but for now return empty
      return [
        { text: "'root'", type: 'value' as const, description: 'Root module' },
      ].filter(s => s.text.toLowerCase().includes(cleanPartial));

    default:
      return [];
  }
}

/**
 * Replace the current word with the selected suggestion
 */
export function applySuggestion(
  query: string,
  cursorPos: number,
  suggestion: string
): { newQuery: string; newCursorPos: number } {
  const { wordStart } = getCurrentWord(query, cursorPos);

  // Find word end
  let wordEnd = cursorPos;
  while (wordEnd < query.length && /[a-zA-Z0-9_:'"]/.test(query[wordEnd])) {
    wordEnd++;
  }

  // Replace word with suggestion
  const before = query.substring(0, wordStart);
  const after = query.substring(wordEnd);
  const newQuery = before + suggestion + after;
  const newCursorPos = wordStart + suggestion.length;

  return { newQuery, newCursorPos };
}
