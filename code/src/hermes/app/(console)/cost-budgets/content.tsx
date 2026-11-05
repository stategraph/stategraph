"use client";

import { PaintedDoorPage } from "@/components/product";
import { getProductById } from "@/config/products";

export function CostBudgetsContent() {
  const product = getProductById("cost-budgets")!;
  return (
    <PaintedDoorPage
      product={product}
      headline="Budgets that span every cloud"
      pitch="Set monthly cost targets scoped by tag — across AWS, GCP, and Azure at once — and see projected overruns before they land. Built on the cost of the infrastructure you actually have in state, not a single provider's bill."
    />
  );
}
