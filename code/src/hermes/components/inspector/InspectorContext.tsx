"use client";

import React, { createContext, useState, useMemo, useCallback, ReactNode } from "react";

/**
 * InspectorResource represents a resource that can be displayed in the Inspector Panel
 */
export interface InspectorResource {
  id?: string;
  address: string;
  type: string;
  provider?: string;
  modulePath?: string;
  summary?: string;
  tags?: Record<string, string>;
  attributes?: Record<string, unknown>;
  dependencyCount?: number;
  dependentCount?: number;
  instanceCount?: number;
}

/**
 * InspectorContextValue provides state and actions for the Inspector Panel
 */
export interface InspectorContextValue {
  isOpen: boolean;
  resource: InspectorResource | null;
  openInspector: (resource: InspectorResource) => void;
  closeInspector: () => void;
}

/**
 * InspectorContext - Global context for managing Inspector Panel state
 */
export const InspectorContext = createContext<InspectorContextValue | undefined>(
  undefined
);

/**
 * InspectorProvider - Provider component for Inspector Panel context
 */
export function InspectorProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [resource, setResource] = useState<InspectorResource | null>(null);

  const openInspector = useCallback((newResource: InspectorResource) => {
    setResource(newResource);
    setIsOpen(true);
  }, []);

  const closeInspector = useCallback(() => {
    setIsOpen(false);
    // Keep resource for a moment to allow exit animation if needed
    setTimeout(() => setResource(null), 150);
  }, []);

  const value = useMemo(
    () => ({
      isOpen,
      resource,
      openInspector,
      closeInspector,
    }),
    [isOpen, resource, openInspector, closeInspector]
  );

  return (
    <InspectorContext.Provider value={value}>
      {children}
    </InspectorContext.Provider>
  );
}

/**
 * useInspector - Hook to access Inspector Panel context
 */
export function useInspector(): InspectorContextValue {
  const context = React.useContext(InspectorContext);
  if (context === undefined) {
    throw new Error("useInspector must be used within an InspectorProvider");
  }
  return context;
}
