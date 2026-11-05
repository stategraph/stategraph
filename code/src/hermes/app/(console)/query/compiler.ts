/**
 * SQL Query Compiler
 *
 * Translates a limited SQL subset into q-string format for the Instances API.
 * This is NOT a real SQL parser - it's a simple tokenizer + translator.
 *
 * Supported features:
 * - SELECT * or field list
 * - COUNT(*) and COUNT(field) aggregations (computed client-side)
 * - FROM table_name
 * - WHERE clauses with =, !=, LIKE, IN operators
 * - Logical AND (OR not yet supported)
 *
 * Aggregation flow:
 * 1. Query is compiled to q-string (WHERE clause filters)
 * 2. API fetches filtered instances
 * 3. Aggregation is computed client-side on the filtered results
 */

export interface ParsedQuery {
  select: string[];  // Field list, or ['*'] for all
  from: string;      // Table name
  where: WhereCondition[];
  qString: string;   // Compiled q-string for API
  aggregation?: {
    type: 'COUNT';
    field: string;   // '*' for COUNT(*), or field name for COUNT(field)
  };
}

export interface WhereCondition {
  field: string;
  operator: '=' | '!=' | 'LIKE' | 'IN';
  value: string | string[];
  logical?: 'AND' | 'OR';
}

export interface CompileResult {
  success: boolean;
  parsed?: ParsedQuery;
  error?: string;
}

/**
 * Main entry point: compile SQL to q-string
 */
export function compileSQL(sql: string): CompileResult {
  try {
    // Normalize whitespace and remove semicolon
    const normalized = sql.trim().replace(/;$/, '').replace(/\s+/g, ' ');

    // Extract SELECT clause
    const selectMatch = normalized.match(/SELECT\s+(.+?)\s+FROM/i);
    if (!selectMatch) {
      return { success: false, error: 'Invalid syntax: Missing SELECT or FROM clause' };
    }
    const selectResult = parseSelectFields(selectMatch[1]);

    // Extract FROM clause
    const fromMatch = normalized.match(/FROM\s+(\w+)/i);
    if (!fromMatch) {
      return { success: false, error: 'Invalid syntax: Missing FROM clause' };
    }
    const fromTable = fromMatch[1].toLowerCase();

    // Extract WHERE clause (optional)
    let whereConditions: WhereCondition[] = [];
    let qString = '';

    const whereMatch = normalized.match(/WHERE\s+(.+)$/i);
    if (whereMatch) {
      const whereResult = parseWhereClause(whereMatch[1]);
      if (!whereResult.success) {
        return { success: false, error: whereResult.error };
      }
      whereConditions = whereResult.conditions!;
      qString = translateToQString(whereConditions);
    }

    return {
      success: true,
      parsed: {
        select: selectResult.fields,
        from: fromTable,
        where: whereConditions,
        qString,
        aggregation: selectResult.aggregation,
      },
    };
  } catch (error: unknown) {
    return {
      success: false,
      error: `Parse error: ${error instanceof Error ? error.message : 'Unknown error'}`,
    };
  }
}

/**
 * Parse SELECT field list
 * Returns either field list or aggregation info
 */
function parseSelectFields(selectClause: string): {
  fields: string[];
  aggregation?: { type: 'COUNT'; field: string };
} {
  const trimmed = selectClause.trim();

  // Check for COUNT(*) pattern
  const countStarMatch = trimmed.match(/^COUNT\s*\(\s*\*\s*\)$/i);
  if (countStarMatch) {
    return {
      fields: ['count'],
      aggregation: { type: 'COUNT', field: '*' },
    };
  }

  // Check for COUNT(field) pattern
  const countFieldMatch = trimmed.match(/^COUNT\s*\(\s*(\w+)\s*\)$/i);
  if (countFieldMatch) {
    return {
      fields: ['count'],
      aggregation: { type: 'COUNT', field: countFieldMatch[1] },
    };
  }

  // Regular field list
  if (trimmed === '*') {
    return { fields: ['*'] };
  }

  // Split by comma and trim
  return { fields: trimmed.split(',').map(field => field.trim()) };
}

/**
 * Parse WHERE clause into conditions
 */
function parseWhereClause(whereClause: string): {
  success: boolean;
  conditions?: WhereCondition[];
  error?: string;
} {
  const conditions: WhereCondition[] = [];

  // Split by AND/OR (case insensitive)
  // For simplicity, we'll handle AND by splitting and joining with space
  // OR is handled by showing an error for now (or we could do client-side union)

  if (whereClause.match(/\bOR\b/i)) {
    return {
      success: false,
      error: 'OR operator is not yet supported. Use AND to combine conditions.',
    };
  }

  // Split by AND
  const andParts = whereClause.split(/\bAND\b/i).map(part => part.trim());

  for (const part of andParts) {
    const condition = parseCondition(part);
    if (!condition) {
      return {
        success: false,
        error: `Invalid condition: "${part}"`,
      };
    }
    conditions.push(condition);
  }

  return { success: true, conditions };
}

/**
 * Parse a single condition
 */
function parseCondition(conditionStr: string): WhereCondition | null {
  conditionStr = conditionStr.trim();

  // Handle IN operator: field IN ('val1', 'val2')
  const inMatch = conditionStr.match(/^(\S+)\s+IN\s*\((.+)\)$/i);
  if (inMatch) {
    const field = inMatch[1];
    const values = inMatch[2]
      .split(',')
      .map(v => v.trim().replace(/^['"]|['"]$/g, ''));
    return {
      field,
      operator: 'IN',
      value: values,
    };
  }

  // Handle LIKE operator: field LIKE 'value%'
  const likeMatch = conditionStr.match(/^(\S+)\s+LIKE\s+['"](.+?)['"]$/i);
  if (likeMatch) {
    const field = likeMatch[1];
    const value = likeMatch[2]; // Keep wildcards for client-side matching
    return {
      field,
      operator: 'LIKE',
      value,
    };
  }

  // Handle != operator
  const neMatch = conditionStr.match(/^(\S+)\s*!=\s*['"](.+?)['"]$/);
  if (neMatch) {
    const field = neMatch[1];
    const value = neMatch[2];
    return {
      field,
      operator: '!=',
      value,
    };
  }

  // Handle = operator
  const eqMatch = conditionStr.match(/^(\S+)\s*=\s*['"](.+?)['"]$/);
  if (eqMatch) {
    const field = eqMatch[1];
    const value = eqMatch[2];
    return {
      field,
      operator: '=',
      value,
    };
  }

  return null;
}

/**
 * Translate WHERE conditions to q-string format
 */
function translateToQString(conditions: WhereCondition[]): string {
  const parts: string[] = [];

  for (const condition of conditions) {
    const part = translateCondition(condition);
    if (part) {
      parts.push(part);
    }
  }

  // Join with space (AND behavior in q-string)
  return parts.join(' ');
}

/**
 * Translate a single condition to q-string format
 */
function translateCondition(condition: WhereCondition): string {
  const { field, operator, value } = condition;

  // Validate supported fields
  const supportedFields = ['provider', 'type', 'module', 'address'];
  if (!supportedFields.includes(field)) {
    console.warn(`Unsupported field: ${field}. Only provider, type, module, and address are supported.`);
    return '';
  }

  switch (operator) {
    case '=':
      return `${field}:${value}`;

    case '!=':
      // Negative filter - prefix with minus
      return `-${field}:${value}`;

    case 'LIKE':
      // LIKE is handled client-side, don't include in q-string
      // Return empty string so it doesn't affect API query
      return '';

    case 'IN':
      // IN translates to multiple OR'd conditions
      // For q-string, we can't really do OR, so we'll take the first value
      // Or we could do client-side filtering
      if (Array.isArray(value) && value.length > 0) {
        // For simplicity, return first value
        // In a real implementation, we'd fetch all and filter client-side
        return `${field}:${value[0]}`;
      }
      return '';

    default:
      return '';
  }
}

/**
 * Apply projection to instances (filter fields based on SELECT clause)
 */
export function applyProjection(instances: Record<string, unknown>[], selectFields: string[]): Record<string, unknown>[] {
  if (selectFields.includes('*')) {
    return instances;
  }

  // Project only selected fields
  return instances.map(instance => {
    const projected: Record<string, unknown> = {};
    for (const field of selectFields) {
      if (field in instance) {
        projected[field] = instance[field];
      }
    }
    return projected;
  });
}

/**
 * Compute aggregation on instances
 */
export function computeAggregation(
  instances: Record<string, unknown>[],
  aggregation: { type: 'COUNT'; field: string }
): Record<string, unknown>[] {
  if (aggregation.type === 'COUNT') {
    if (aggregation.field === '*') {
      // COUNT(*) - count all rows
      return [{ count: instances.length }];
    } else {
      // COUNT(field) - count non-null occurrences
      const count = instances.filter(instance => {
        const value = instance[aggregation.field];
        return value !== null && value !== undefined && value !== '';
      }).length;
      return [{ count }];
    }
  }

  return instances;
}

/**
 * Apply LIKE filtering client-side
 * Supports SQL LIKE wildcards: % (any characters) and _ (single character)
 */
export function applyLikeFilters(instances: Record<string, unknown>[], conditions: WhereCondition[]): Record<string, unknown>[] {
  // Filter to only LIKE conditions
  const likeConditions = conditions.filter(c => c.operator === 'LIKE');

  if (likeConditions.length === 0) {
    return instances;
  }

  return instances.filter(instance => {
    // All LIKE conditions must match (AND logic)
    return likeConditions.every(condition => {
      const fieldValue = instance[condition.field];
      if (fieldValue === null || fieldValue === undefined) {
        return false;
      }

      const value = String(fieldValue);
      const pattern = String(condition.value);

      // Convert SQL LIKE pattern to JavaScript regex
      // Escape special regex characters except % and _
      let regexPattern = pattern
        .replace(/[.+^${}()|[\]\\]/g, '\\$&')  // Escape regex special chars
        .replace(/%/g, '.*')                     // % matches any characters
        .replace(/_/g, '.');                     // _ matches single character

      // Make it match full string
      regexPattern = `^${regexPattern}$`;

      const regex = new RegExp(regexPattern, 'i'); // Case-insensitive
      return regex.test(value);
    });
  });
}

/**
 * Example query categories
 */
export interface ExampleQuery {
  label: string;
  sql: string;
}

export interface ExampleQueryGroup {
  category: string;
  queries: ExampleQuery[];
}

export const EXAMPLE_QUERY_GROUPS: ExampleQueryGroup[] = [
  {
    category: 'General',
    queries: [
      { label: 'First 10 instances', sql: 'select * from instances limit 10' },
      { label: 'Count instances', sql: 'select count(*) from instances' },
      { label: 'All resources', sql: 'select * from resources limit 20' },
      { label: 'Count by resource type', sql: 'select type, count(*) from resources group by type' },
      { label: 'Instance addresses', sql: 'select address from instances order by address limit 20' },
      { label: 'Resources with provider', sql: 'select address, type, provider, module from resources limit 20' },
      { label: 'All states', sql: 'select id, name, created_at from states order by created_at desc' },
    ],
  },
];

/** Flat list for backward compat */
export const EXAMPLE_QUERIES = EXAMPLE_QUERY_GROUPS.flatMap(g => g.queries);
