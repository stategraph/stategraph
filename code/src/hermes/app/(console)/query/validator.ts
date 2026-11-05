/**
 * MQL Validator for Query Editor
 *
 * Provides lightweight real-time validation with error highlighting.
 * Uses simple regex patterns - NO heavy parsing or SQL grammar.
 *
 * Note: MQL backend does full validation. This is just for basic syntax checks.
 */

export interface ValidationError {
  message: string;
  severity: 'error' | 'warning';
  startIndex: number;
  endIndex: number;
  line?: number;
  column?: number;
}

export interface ValidationResult {
  isValid: boolean;
  errors: ValidationError[];
  hasFatalErrors: boolean;
}

/**
 * Main validation entry point
 *
 * Note: MQL backend handles full validation (tables, columns, operators, etc.).
 * This is just lightweight syntax checking for basic UX feedback.
 */
export function validateSQL(sql: string): ValidationResult {
  const errors: ValidationError[] = [];
  const normalized = sql.trim();

  if (!normalized) {
    return { isValid: true, errors: [], hasFatalErrors: false };
  }

  // Remove trailing semicolon for parsing
  const withoutSemicolon = normalized.replace(/;$/, '');

  // Rule 1: SELECT clause must exist
  const selectMatch = withoutSemicolon.match(/SELECT\s+/i);
  if (!selectMatch) {
    errors.push({
      message: 'SELECT clause is required',
      severity: 'error',
      startIndex: 0,
      endIndex: Math.min(6, normalized.length),
    });
  }

  // Rule 2: FROM clause should exist
  const fromMatch = withoutSemicolon.match(/FROM\s+(\w+)/i);
  if (!fromMatch) {
    // Try to find if FROM exists at all
    const fromKeywordMatch = normalized.match(/FROM\s*/i);
    if (!fromKeywordMatch && selectMatch) {
      // FROM is missing entirely
      const selectIndex = normalized.indexOf(selectMatch[0]);
      const afterSelect = selectIndex + selectMatch[0].length;
      errors.push({
        message: 'FROM clause is required',
        severity: 'warning',
        startIndex: afterSelect,
        endIndex: afterSelect + 4,
      });
    }
  }

  // Rule 4: Check for double quotes (should use single quotes for strings)
  const doubleQuoteMatch = normalized.match(/"([^"]*)"/);
  if (doubleQuoteMatch) {
    const index = normalized.indexOf(doubleQuoteMatch[0]);
    errors.push({
      message: 'String literals must use single quotes',
      severity: 'error',
      startIndex: index,
      endIndex: index + doubleQuoteMatch[0].length,
    });
  }

  // Rule 5: Check for OR operator (not yet supported)
  const orMatch = normalized.match(/\bOR\b/i);
  if (orMatch) {
    const index = normalized.search(/\bOR\b/i);
    errors.push({
      message: 'OR operator is not yet supported',
      severity: 'error',
      startIndex: index,
      endIndex: index + 2,
    });
  }

  // Note: Other validations (columns, complex operators, etc.) handled by MQL backend

  const hasFatalErrors = errors.some(e => e.severity === 'error');

  return {
    isValid: errors.length === 0,
    errors,
    hasFatalErrors,
  };
}
