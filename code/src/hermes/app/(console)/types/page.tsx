"use client";

import { AuthGuard } from "@/components/auth";
import { ResourceTypesContent } from "./content";

export default function ResourceTypesPage() {
  return (
    <AuthGuard>
      <ResourceTypesContent />
    </AuthGuard>
  );
}
