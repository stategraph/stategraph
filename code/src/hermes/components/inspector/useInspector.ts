"use client";

import { useContext } from "react";
import { InspectorContext, InspectorContextValue } from "./InspectorContext";

/**
 * useInspector hook - Access the Inspector Panel context
 *
 * @throws Error if used outside InspectorProvider
 * @returns InspectorContextValue with state and actions
 */
export function useInspector(): InspectorContextValue {
  const context = useContext(InspectorContext);

  if (context === undefined) {
    throw new Error(
      "useInspector must be used within an InspectorProvider. " +
      "Make sure your component is wrapped with <InspectorProvider>."
    );
  }

  return context;
}
