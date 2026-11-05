"use client";

import React from "react";
import { Lightbulb } from "lucide-react";

interface SuggestedQueriesProps {
  onSelectQuery: (q: string) => void;
}

const SUGGESTED_QUERIES = [
  {
    q: "type:aws_s3_bucket",
    description: "S3 buckets",
  },
  {
    q: "type:aws_lambda_function",
    description: "Lambda functions",
  },
  {
    q: "type:aws_iam_role",
    description: "IAM roles",
  },
  {
    q: "module:vpc",
    description: "VPC module resources",
  },
  {
    q: "type:google_storage_bucket",
    description: "Cloud Storage buckets",
  },
  {
    q: "module:root",
    description: "Root module resources",
  },
];

export function SuggestedQueries({ onSelectQuery }: SuggestedQueriesProps) {
  return (
    <div className="space-y-3">
      <div className="flex items-center gap-2">
        <Lightbulb className="h-4 w-4 text-[var(--sg-warning)]" />
        <h3 className="sg-secondary-header">Suggested Queries</h3>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
        {SUGGESTED_QUERIES.map((query) => (
          <button
            key={query.q}
            onClick={() => onSelectQuery(query.q)}
            className="flex flex-col items-start gap-1 p-3 bg-[var(--sg-bg-2)] border border-[var(--sg-border)] rounded-lg hover:border-[var(--sg-accent)] hover:bg-[var(--sg-bg-1)] transition-colors text-left group"
          >
            <code className="text-xs font-mono text-[var(--sg-accent)] group-hover:text-[var(--sg-accent-hover)]">
              {query.q}
            </code>
            <span className="sg-metadata">{query.description}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
