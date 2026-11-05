"use client";

import { PaintedDoorPage } from "@/components/product";
import { getProductById } from "@/config/products";

export function CostOptimizationContent() {
  const product = getProductById("cost-optimization")!;
  return (
    <PaintedDoorPage
      product={product}
      headline="Find the spend worth cutting"
      pitch="Rightsizing, idle-resource, and modernization recommendations across your whole estate — ranked by impact and attributed to the states and modules that own them."
    />
  );
}
