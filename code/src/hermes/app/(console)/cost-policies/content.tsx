"use client";

import { PaintedDoorPage } from "@/components/product";
import { getProductById } from "@/config/products";

export function CostPoliciesContent() {
  const product = getProductById("cost-policies")!;
  return (
    <PaintedDoorPage
      product={product}
      headline="Cost guardrails in the pull request"
      pitch="Block or flag changes that blow past a cost threshold, right in your orchestration pull-request flow — before they're applied. Plan-time preview pricing plugs in here as it lands."
    />
  );
}
