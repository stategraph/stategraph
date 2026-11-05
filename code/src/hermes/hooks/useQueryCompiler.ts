"use client";

import { useCallback } from 'react';
import { QueryObject, compileQuery, parseQuery } from '@/lib/query';

/**
 * useQueryCompiler - Compile and parse queries
 *
 * Provides memoized functions for query compilation and parsing
 */
export function useQueryCompiler() {
  // Compile QueryObject to string
  const compile = useCallback((query: QueryObject): string => {
    return compileQuery(query);
  }, []);

  // Parse string to QueryObject
  const parse = useCallback((q: string): QueryObject => {
    return parseQuery(q);
  }, []);

  return {
    compile,
    parse,
  };
}
