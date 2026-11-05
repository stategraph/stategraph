import { Product } from "@/config/products";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Bell, ExternalLink } from "lucide-react";

export interface ComingSoonPageProps {
  product: Product;
  estimatedRelease?: string;
}

export function ComingSoonPage({
  product,
  estimatedRelease,
}: ComingSoonPageProps) {
  const Icon = product.icon;

  return (
    <div className="flex flex-col items-center justify-center min-h-[600px] px-6">
      <Card className="max-w-2xl w-full">
        <CardContent className="flex flex-col items-center text-center p-6 sm:p-12">
          {/* Icon */}
          <div
            className="w-20 h-20 rounded-full flex items-center justify-center mb-6"
            style={{
              background: "var(--sg-accent-bg)",
              border: "2px solid var(--sg-border)",
            }}
          >
            <Icon
              className="w-10 h-10"
              style={{ color: "var(--sg-accent)" }}
            />
          </div>

          {/* Title with Badge */}
          <div className="flex flex-wrap items-center justify-center gap-3 mb-3">
            <h1
              className="text-3xl font-bold"
              style={{ color: "var(--sg-text)" }}
            >
              {product.label}
            </h1>
            <Badge variant="secondary">Coming Soon</Badge>
          </div>

          {/* Estimated Release */}
          {estimatedRelease && (
            <p
              className="text-sm mb-4"
              style={{ color: "var(--sg-text-muted)" }}
            >
              Expected: {estimatedRelease}
            </p>
          )}

          {/* Description */}
          <p
            className="text-lg mb-8 max-w-xl"
            style={{ color: "var(--sg-text-muted)" }}
          >
            {product.description}
          </p>

          {/* Planned Features */}
          {product.features && product.features.length > 0 && (
            <div className="w-full mb-8">
              <h2
                className="text-sm font-semibold mb-4 uppercase tracking-wide"
                style={{ color: "var(--sg-text-dim)" }}
              >
                Planned Features
              </h2>
              <ul className="grid grid-cols-1 md:grid-cols-2 gap-3 text-left">
                {product.features.map((feature, index) => (
                  <li
                    key={index}
                    className="flex items-start gap-2"
                    style={{ color: "var(--sg-text)" }}
                  >
                    <span
                      className="text-xs mt-1"
                      style={{ color: "var(--sg-accent)" }}
                    >
                      ▪
                    </span>
                    <span className="text-sm">{feature}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex flex-wrap justify-center gap-3">
            <Button
              variant="default"
              disabled
              className="gap-2"
            >
              <Bell className="w-4 h-4" />
              Notify Me
            </Button>
            <Button
              variant="outline"
              disabled
              className="gap-2"
            >
              <ExternalLink className="w-4 h-4" />
              Learn More
            </Button>
          </div>

          {/* Note */}
          <p
            className="text-xs mt-8"
            style={{ color: "var(--sg-text-dim)" }}
          >
            This feature is currently in development. Check back later for
            updates.
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
