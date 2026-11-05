"use client";

import { usePathname } from "next/navigation";
import { DeepLink } from "@/components/navigation";
import { cn } from "@/lib/utils";
import { mainNav, accountNav, navEntryActive, navForMode, type Product } from "@/config/products";
import { Building2, LogOut, X } from "lucide-react";
import { logout } from "@/lib/api/client";
import { trackLogout } from "@/lib/analytics";
import { useVersion, useLicense, useTenant } from "@/contexts";
import { SidebarTenantSelector } from "@/components/tenant/SidebarTenantSelector";
import { TenantSelector } from "@/components/tenant/TenantSelector";
import { SlackIcon } from "@/components/ui/brand-icons";

interface SidebarProps {
  /** Whether the off-canvas drawer is open (mobile/tablet only). */
  open?: boolean;
  /** Close the off-canvas drawer (mobile/tablet only). */
  onClose?: () => void;
}

export function Sidebar({ open = false, onClose }: SidebarProps) {
  const pathname = usePathname();
  const { updateAvailable } = useVersion();
  const { mode } = useLicense();
  const { tenants, currentTenant } = useTenant();
  // In COMMUNISM mode users don't self-upgrade, so suppress the settings
  // update dot just like the upgrade banner.
  const showUpdateDot = mode !== "COMMUNISM" && updateAvailable;

  return (
    <aside
      className={cn(
        "flex flex-col bg-[var(--sg-bg-1)] border-r border-[var(--sg-border)] h-screen",
        "w-[var(--sg-sidebar-width)] max-w-[85vw]",
        // Off-canvas drawer on mobile/tablet …
        "fixed inset-y-0 left-0 z-50 transform transition-transform duration-200 ease-in-out",
        open ? "translate-x-0" : "-translate-x-full",
        // … static, always-visible column on lg+
        "lg:sticky lg:top-0 lg:z-auto lg:max-w-none lg:translate-x-0"
      )}
    >
      {/* Logo / Brand */}
      <div
        className="border-b border-[var(--sg-border)] flex-shrink-0"
      >
        <div
          className="flex items-center justify-between px-5"
          style={{ height: "var(--sg-nav-height)" }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_white.svg"
            alt="Stategraph"
            className="h-10 hidden dark:block"
          />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_blue.svg"
            alt="Stategraph"
            className="h-10 dark:hidden"
          />
          {/* Close drawer — mobile/tablet only */}
          <button
            type="button"
            onClick={onClose}
            className="lg:hidden -mr-2 p-2 rounded-md text-[var(--sg-text-muted)] hover:bg-[var(--sg-bg-2)] hover:text-[var(--sg-text)] transition-colors"
            aria-label="Close navigation menu"
          >
            <X className="h-5 w-5" />
          </button>
        </div>
        {tenants.length > 1 ? (
          <div className="px-6 pb-3">
            <div className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--sg-text-dim)]">Tenant</div>
            <div className="flex items-center gap-3">
              <NavIconChip icon={Building2} active={false} />
              <div className="min-w-0 flex-1">
                <TenantSelector />
              </div>
            </div>
          </div>
        ) : currentTenant ? (
          <div className="px-3 pb-3">
            <div className="mb-2 px-3 text-xs font-medium uppercase tracking-wider text-[var(--sg-text-dim)]">Tenant</div>
            <DeepLink
              href="/settings?tab=tenant"
              title="Tenant settings"
              className="group flex items-center gap-3 rounded-lg px-3 py-2 transition-colors duration-150 hover:bg-[var(--sg-bg-2)]"
            >
              <NavIconChip icon={Building2} active={false} />
              <span className="min-w-0 flex-1 truncate text-[0.95rem] font-medium leading-tight text-[var(--sg-text)]">
                {currentTenant.name}
              </span>
            </DeepLink>
          </div>
        ) : null}
        <div className="px-3 pb-3">
          <a
            href="https://stategraph.com/slack"
            target="_blank"
            rel="noopener noreferrer"
            className="group flex items-center gap-3 rounded-lg px-3 py-2 transition-colors duration-150 hover:bg-[var(--sg-bg-2)]"
          >
            <NavIconChip icon={SlackIcon} active={false} />
            <span className="flex-1 min-w-0">
              <span className="block text-[0.95rem] font-medium leading-tight text-[var(--sg-text)]">Join our Slack</span>
              <span className="block text-xs leading-tight mt-0.5 text-[var(--sg-text-dim)]">Community and help</span>
            </span>
          </a>
        </div>
      </div>

      {/* Personal-tenant block — renders only in COMMUNISM mode. */}
      <SidebarTenantSelector />

      {/* Navigation — one item per product area; an active area lists its
          screens as indented child rows so each is a one-click destination */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {navForMode(mainNav, mode).map((entry) => {
          const active = navEntryActive(entry, pathname);
          return (
            <div key={entry.product.id}>
              <NavLink product={entry.product} active={active} />
              {active && entry.children && entry.children.length > 0 && (
                <div className="mt-1 space-y-0.5">
                  {entry.children.map((child) => (
                    <ChildNavLink
                      key={child.product.id}
                      product={child.product}
                      active={navEntryActive(child, pathname)}
                    />
                  ))}
                </div>
              )}
            </div>
          );
        })}
      </nav>

      {/* Footer - Account */}
      <div className="px-3 py-4 border-t border-[var(--sg-border)] flex-shrink-0 space-y-1">
        {accountNav.map((entry) => (
          <NavLink
            key={entry.product.id}
            product={entry.product}
            active={navEntryActive(entry, pathname)}
            showBadge={entry.product.id === "settings" && showUpdateDot}
          />
        ))}
        <UtilityLink
          href="#"
          icon={LogOut}
          label="Logout"
          onClick={(e) => {
            e.preventDefault();
            trackLogout();
            logout();
          }}
        />
      </div>

    </aside>
  );
}

interface NavLinkProps {
  product: Product;
  active?: boolean;
  showBadge?: boolean;
}

function NavLink({ product, active = false, showBadge = false }: NavLinkProps) {
  const Icon = product.icon;

  if (product.status === "coming_soon") {
    // Roadmap items: visually identical to inactive available items, no interaction
    return (
      <div className="relative flex items-center gap-3 rounded-md px-3 py-2.5 text-sm text-[var(--sg-text-muted)] cursor-default">
        <Icon className="h-4 w-4 flex-shrink-0 text-[var(--sg-text-dim)]" />
        <span className="flex-1 whitespace-nowrap overflow-hidden text-ellipsis">
          {product.label}
        </span>
      </div>
    );
  }

  return (
    <DeepLink
      href={product.href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "group relative flex items-center gap-3 rounded-lg px-3 py-2.5 transition-colors duration-150",
        active
          ? "bg-[var(--sg-accent-bg-active)] shadow-sm" /* Stronger background for active items in light mode */
          : "hover:bg-[var(--sg-bg-2)]"
      )}
    >
      {active && (
        <div className="absolute left-0 top-0 bottom-0 w-0.5 bg-[var(--sg-accent)] rounded-r" />
      )}
      <NavIconChip icon={Icon} active={active} />
      <span className="flex-1 min-w-0">
        <span
          className={cn(
            "block text-[0.95rem] font-medium leading-tight whitespace-nowrap overflow-hidden text-ellipsis",
            active ? "text-[var(--sg-accent)]" : "text-[var(--sg-text)]"
          )}
        >
          {product.label}
        </span>
        {product.navTagline && (
          <span
            className={cn(
              "block text-xs leading-tight mt-0.5 whitespace-nowrap overflow-hidden text-ellipsis",
              active ? "text-[var(--sg-accent)]/70" : "text-[var(--sg-text-dim)]"
            )}
          >
            {product.navTagline}
          </span>
        )}
      </span>
      {showBadge && (
        <span className="h-2 w-2 rounded-full bg-[var(--sg-warning)] flex-shrink-0" />
      )}
    </DeepLink>
  );
}

/** Indented sub-screen row shown under its area while the area is active. */
function ChildNavLink({ product, active }: { product: Product; active: boolean }) {
  const Icon = product.icon;

  if (product.status === "coming_soon") {
    // Roadmap items: the same non-interactive row NavLink renders for them
    return (
      <div className="relative flex items-center gap-2.5 rounded-md py-1.5 pl-12 pr-3 text-sm text-[var(--sg-text-muted)] cursor-default">
        <Icon className="h-4 w-4 flex-shrink-0 text-[var(--sg-text-dim)]" />
        <span className="whitespace-nowrap overflow-hidden text-ellipsis">{product.label}</span>
      </div>
    );
  }

  return (
    <DeepLink
      href={product.href}
      aria-current={active ? "page" : undefined}
      className={cn(
        "group relative flex items-center gap-2.5 rounded-md py-1.5 pl-12 pr-3 text-sm transition-colors duration-150",
        active
          ? "bg-[var(--sg-accent-bg-active)] text-[var(--sg-accent)] font-medium"
          : "text-[var(--sg-text-muted)] hover:bg-[var(--sg-bg-2)] hover:text-[var(--sg-text)]"
      )}
    >
      {active && (
        <div className="absolute left-0 top-0 bottom-0 w-0.5 bg-[var(--sg-accent)] rounded-r" />
      )}
      <Icon className="h-4 w-4 flex-shrink-0" />
      <span className="whitespace-nowrap overflow-hidden text-ellipsis">{product.label}</span>
    </DeepLink>
  );
}

interface UtilityLinkProps {
  href: string;
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  active?: boolean;
  onClick?: (e: React.MouseEvent<HTMLAnchorElement>) => void;
}

function UtilityLink({ href, icon: Icon, label, active = false, onClick }: UtilityLinkProps) {
  return (
    <DeepLink
      href={href}
      onClick={onClick}
      className={cn(
        "group relative flex items-center gap-3 rounded-lg px-3 py-2.5 text-[0.95rem] font-medium transition-colors duration-150",
        active
          ? "bg-[var(--sg-accent-bg-active)] text-[var(--sg-accent)] font-medium shadow-sm"
          : "text-[var(--sg-text)] hover:bg-[var(--sg-bg-2)]"
      )}
    >
      <NavIconChip icon={Icon} active={active} />
      <span className="flex-1 whitespace-nowrap overflow-hidden text-ellipsis">{label}</span>
    </DeepLink>
  );
}

interface NavIconChipProps {
  icon: React.ComponentType<{ className?: string }>;
  active: boolean;
}

/** Icon chip at the head of every sidebar row — each nav item reads as a product. */
function NavIconChip({ icon: Icon, active }: NavIconChipProps) {
  return (
    <span
      className={cn(
        "flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-lg border transition-colors duration-150",
        active
          ? "border-[var(--sg-accent)]/30 bg-[var(--sg-accent-bg)] text-[var(--sg-accent)]"
          : "border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-[var(--sg-text-dim)] group-hover:text-[var(--sg-text-muted)]"
      )}
    >
      <Icon className="h-[18px] w-[18px]" />
    </span>
  );
}
