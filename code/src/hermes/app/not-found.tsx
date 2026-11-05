import Link from "next/link";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { FileQuestion } from "lucide-react";

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-[600px] px-6">
      <Card className="max-w-2xl w-full">
        <CardContent className="flex flex-col items-center text-center p-12">
          {/* Icon */}
          <div
            className="w-20 h-20 rounded-full flex items-center justify-center mb-6"
            style={{
              background: "var(--sg-bg-2)",
              border: "2px solid var(--sg-border)",
            }}
          >
            <FileQuestion
              className="w-10 h-10"
              style={{ color: "var(--sg-text-dim)" }}
            />
          </div>

          {/* Title */}
          <h1
            className="text-3xl font-bold mb-3"
            style={{ color: "var(--sg-text)" }}
          >
            Page not found
          </h1>

          {/* Description */}
          <p
            className="text-lg mb-8 max-w-xl"
            style={{ color: "var(--sg-text-muted)" }}
          >
            The page you&apos;re looking for doesn&apos;t exist or may have moved.
          </p>

          {/* Action Buttons */}
          <div className="flex gap-3">
            <Button variant="default" asChild>
              <Link href="/">Go to Home</Link>
            </Button>
            <Button variant="outline" asChild>
              <Link href="/instances">View Resources</Link>
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
