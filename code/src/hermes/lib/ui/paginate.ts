/**
 * Pure pagination math, shared by the usePagination hook so it can be unit
 * tested without a React renderer.
 */
export interface PageBounds {
  totalPages: number;
  page: number; // clamped into [1, totalPages]
  start: number; // inclusive slice start
  end: number; // exclusive slice end
  hasNext: boolean;
  hasPrevious: boolean;
}

export function pageBounds(total: number, page: number, pageSize: number): PageBounds {
  const size = Math.max(1, Math.floor(pageSize));
  const totalPages = Math.max(1, Math.ceil(Math.max(0, total) / size));
  const clamped = Math.min(Math.max(1, Math.floor(page) || 1), totalPages);
  const start = (clamped - 1) * size;
  const end = Math.min(start + size, Math.max(0, total));
  return {
    totalPages,
    page: clamped,
    start,
    end,
    hasNext: clamped < totalPages,
    hasPrevious: clamped > 1,
  };
}
