"use client";

import { useState } from "react";
import { Product } from "@/config/products";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { ArrowRight, Check, ExternalLink, Mail } from "lucide-react";
import { track } from "@/lib/analytics";

export interface PaintedDoorPageProps {
  product: Product;
  /** Optional headline override. Defaults to the product label. */
  headline?: string;
  /** Optional pitch shown under the headline. */
  pitch?: string;
  /** Optional secondary CTA — e.g. a link to a real, working surface. */
  primaryLink?: {
    label: string;
    href: string;
    /** Open in a new tab. Defaults to true for external (http) hrefs. */
    external?: boolean;
  };
}

/**
 * "Painted door" landing for products that aren't built yet. Reads as a
 * real product surface (hero + feature preview grid) rather than a
 * disabled "Coming Soon" placeholder, though it still shows a Coming Soon
 * badge when the product's status says so. The "Request early access" button
 * records demand as an analytics event.
 */
export function PaintedDoorPage({
  product,
  headline,
  pitch,
  primaryLink,
}: PaintedDoorPageProps) {
  const Icon = product.icon;
  const [requested, setRequested] = useState(false);
  const linkIsExternal =
    primaryLink?.external ??
    (primaryLink?.href.startsWith("http") || false);

  return (
    <div className="w-full max-w-[1320px] mx-auto px-4 sm:px-6 py-8 sm:py-12 space-y-12 sm:space-y-16">
      {/* Hero */}
      <section className="relative overflow-hidden rounded-2xl border border-[var(--sg-accent)]/30 bg-gradient-to-br from-[var(--sg-accent)]/8 via-[var(--sg-bg-1)] to-[var(--sg-bg-1)]">
        <div className="grid grid-cols-1 md:grid-cols-[1.2fr_1fr] gap-10 items-center px-6 py-10 sm:px-10 sm:py-16">
          <div>
            <div className="flex items-center gap-3 mb-4">
              <span className="text-xs font-semibold uppercase tracking-wider text-[var(--sg-accent)]">
                {product.label}
              </span>
              {product.status === "coming_soon" && <Badge variant="secondary">Coming Soon</Badge>}
            </div>
            <h1 className="text-4xl md:text-5xl font-semibold leading-tight tracking-tight text-[var(--sg-text)]">
              {headline ?? product.label}
            </h1>
            <p className="mt-5 text-base md:text-lg leading-relaxed text-[var(--sg-text-muted)] max-w-xl">
              {pitch ?? product.description}
            </p>
            <div className="mt-9 flex flex-wrap items-center gap-3">
              {primaryLink && (
                <a
                  href={primaryLink.href}
                  target={linkIsExternal ? "_blank" : undefined}
                  rel={linkIsExternal ? "noopener noreferrer" : undefined}
                >
                  <Button
                    type="button"
                    size="lg"
                    className="h-12 px-7 text-base font-semibold shadow-sm"
                  >
                    {primaryLink.label}
                    {linkIsExternal ? (
                      <ExternalLink className="h-5 w-5 ml-2" />
                    ) : (
                      <ArrowRight className="h-5 w-5 ml-2" />
                    )}
                  </Button>
                </a>
              )}
              {/* "Request early access" only makes sense when the product
                  doesn't already ship something the user can click into. */}
              {!primaryLink &&
                (requested ? (
                  <div className="inline-flex items-center gap-2 px-4 py-3 rounded-md border border-[var(--sg-success)]/40 bg-[var(--sg-success)]/8 text-sm text-[var(--sg-text)]">
                    <Check className="h-4 w-4 text-[var(--sg-success)]" />
                    Thanks — we&apos;ll be in touch.
                  </div>
                ) : (
                  <Button
                    type="button"
                    size="lg"
                    onClick={() => {
                      track("early_access_requested", { product: product.id });
                      setRequested(true);
                    }}
                    className="h-12 px-7 text-base font-semibold shadow-sm"
                  >
                    Request early access
                    <ArrowRight className="h-5 w-5 ml-2" />
                  </Button>
                ))}
              <a
                href="mailto:hello@stategraph.com?subject=Interested%20in%20Stategraph"
                className="inline-flex items-center gap-2 text-sm text-[var(--sg-text-muted)] hover:text-[var(--sg-text)] transition-colors"
              >
                <Mail className="h-4 w-4" />
                Talk to us
              </a>
            </div>
            {!primaryLink && (
              <div className="mt-3 text-xs text-[var(--sg-text-dim)]">
                In active development. Your interest helps us prioritize.
              </div>
            )}
          </div>

          <div className="hidden md:flex items-center justify-center">
            <div
              className="h-40 w-40 rounded-2xl flex items-center justify-center"
              style={{
                background:
                  "radial-gradient(circle at 30% 30%, var(--sg-accent-bg) 0%, var(--sg-bg-1) 70%)",
                border: "1px solid var(--sg-border)",
              }}
            >
              <Icon
                className="h-20 w-20"
                style={{ color: "var(--sg-accent)" }}
              />
            </div>
          </div>
        </div>
      </section>

      {/* Feature preview grid — reads as the product's surface area, not a
          "planned features" bullet list. */}
      {product.features && product.features.length > 0 && (
        <section>
          <h2 className="text-xl font-semibold text-[var(--sg-text)]">
            What you&apos;ll get
          </h2>
          <p className="text-sm text-[var(--sg-text-muted)] mt-1.5 max-w-2xl">
            Built on the same graph that powers your states, resources, and
            blast-radius views.
          </p>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5 mt-7">
            {product.features.map((feature) => (
              <div
                key={feature}
                className="px-7 py-6 rounded-xl border-2 border-[var(--sg-border)] bg-[var(--sg-bg-1)] shadow-sm"
              >
                <div className="flex items-start gap-3">
                  <div className="h-9 w-9 rounded-lg bg-[var(--sg-accent-bg)] flex items-center justify-center flex-shrink-0">
                    <Icon className="h-5 w-5 text-[var(--sg-accent)]" />
                  </div>
                  <div className="text-sm text-[var(--sg-text)] leading-relaxed pt-1.5">
                    {feature}
                  </div>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
