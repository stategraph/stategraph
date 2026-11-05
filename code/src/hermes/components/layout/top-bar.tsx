"use client";

import { usePathname } from "next/navigation";
import { useDeepLinkRouter } from "@/hooks";
import { useEffect, useState } from "react";
import { DeepLink } from "@/components/navigation";
import { getProductByHref, mainNav, navEntryActive } from "@/config/products";
import { ChevronRight, Settings, LogOut, Menu } from "lucide-react";
import { ThemeToggle } from "@/components/theme/ThemeToggle";
import { Avatar } from "@/components/ui/avatar";
import { whoami, logout, type User } from "@/lib/api/client";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface TopBarProps {
  /** Open the navigation drawer (mobile/tablet only). */
  onMenuClick?: () => void;
}

export function TopBar({ onMenuClick }: TopBarProps) {
  const pathname = usePathname();
  const router = useDeepLinkRouter();
  const [user, setUser] = useState<User | null>(null);
  const [sessionId, setSessionId] = useState<string | null>(null);

  // Fetch user data on mount
  useEffect(() => {
    async function fetchUser() {
      try {
        const userData = await whoami();
        setUser(userData);
      } catch (_error) {
        // User not authenticated or error - will fall back to sessionId
        // Try to get session ID from localStorage
        const storedSessionId = typeof window !== 'undefined'
          ? localStorage.getItem('stategraph-session-id')
          : null;
        setSessionId(storedSessionId);
      }
    }

    fetchUser();
  }, []);

  // Get current product from pathname
  const product = getProductByHref(pathname);
  // The flat sidebar no longer displays hierarchy, so the breadcrumb supplies
  // it: standalone sub-pages get their owning area as a crumb ("Costs /
  // Overview" on /cost-overview) via the area attribution mainNav already has.
  const area = mainNav.find((e) => navEntryActive(e, pathname))?.product;

  // Build breadcrumbs
  const breadcrumbs: Array<{ label: string; href: string | null; icon?: boolean }> = [
    { label: "Stategraph", href: "/", icon: true },
  ];

  if (area && area !== product) {
    breadcrumbs.push({ label: area.label, href: area.href });
  }
  if (product) {
    breadcrumbs.push({ label: product.label, href: product.href });
  }

  return (
    <header
      className="flex items-center justify-between bg-[var(--sg-bg-0)] border-b border-[var(--sg-border)] px-4 lg:px-6 sticky top-0 z-10"
      style={{ height: "var(--sg-nav-height)" }}
    >
      <div className="flex items-center gap-2 sm:gap-4 min-w-0">
        {/* Hamburger — opens the nav drawer on mobile/tablet */}
        <button
          type="button"
          onClick={onMenuClick}
          className="lg:hidden -ml-1 p-2 rounded-md text-[var(--sg-text-muted)] hover:bg-[var(--sg-bg-2)] hover:text-[var(--sg-text)] transition-colors flex-shrink-0"
          aria-label="Open navigation menu"
        >
          <Menu className="h-5 w-5" />
        </button>

        {/* Dynamic Breadcrumbs */}
        <div className="flex items-center gap-2 text-sm min-w-0 overflow-hidden">
          {breadcrumbs.map((crumb, index) => {
            // The last crumb (current page) may truncate; earlier crumbs keep
            // their full width so the trail stays readable when space is tight.
            const isLast = index === breadcrumbs.length - 1;
            return (
              <div
                key={index}
                className={`flex items-center gap-2 ${isLast ? "min-w-0" : "flex-shrink-0"}`}
              >
                {index > 0 && (
                  <ChevronRight
                    className="h-3 w-3 flex-shrink-0"
                    style={{ color: "var(--sg-text-dim)" }}
                  />
                )}
                {crumb.href ? (
                  <DeepLink
                    href={crumb.href}
                    className="font-medium hover:underline flex items-center min-w-0"
                    style={{ color: "var(--sg-text)" }}
                  >
                    {crumb.icon ? (
                      <>
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src="/logos/stategraph_logo_symbol_blue.svg"
                          alt="Stategraph"
                          className="h-5 w-5"
                        />
                      </>
                    ) : (
                      <span className="truncate">{crumb.label}</span>
                    )}
                  </DeepLink>
                ) : (
                  <span className="truncate" style={{ color: "var(--sg-text-muted)" }}>
                    {crumb.label}
                  </span>
                )}
              </div>
            );
          })}
        </div>
      </div>

      <div className="flex items-center gap-3">
        {/* Theme Toggle */}
        <ThemeToggle />

        {/* User Avatar with Dropdown */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <button
              className="rounded-full hover:opacity-80 transition-opacity focus:outline-none focus:ring-2 focus:ring-[var(--sg-accent)] focus:ring-offset-2 focus:ring-offset-[var(--sg-bg-0)]"
              aria-label="User menu"
            >
              <Avatar user={user} sessionId={sessionId} size={36} />
            </button>
          </DropdownMenuTrigger>
          <DropdownMenuContent
            align="end"
            className="w-64 bg-[var(--sg-bg-1)] border-[var(--sg-border)]"
          >
            {user ? (
              <>
                {/* User Info Header */}
                <DropdownMenuLabel className="font-normal">
                  <div className="flex flex-col gap-1">
                    <p className="text-sm font-medium text-[var(--sg-text)]">
                      {user.name}
                    </p>
                    {user.email && (
                      <p className="text-xs text-[var(--sg-text-muted)] truncate">
                        {user.email}
                      </p>
                    )}
                  </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator className="bg-[var(--sg-border)]" />
              </>
            ) : sessionId ? (
              <>
                <DropdownMenuLabel className="font-normal">
                  <div className="flex flex-col gap-1">
                    <p className="text-sm font-medium text-[var(--sg-text)]">
                      Session User
                    </p>
                    <p className="text-xs text-[var(--sg-text-muted)] font-mono truncate">
                      {sessionId.slice(0, 8)}...
                    </p>
                  </div>
                </DropdownMenuLabel>
                <DropdownMenuSeparator className="bg-[var(--sg-border)]" />
              </>
            ) : null}

            {/* Menu Items */}
            <DropdownMenuItem
              {...router.nav("/settings")}
              className="cursor-pointer text-[var(--sg-text)] focus:bg-[var(--sg-bg-2)] focus:text-[var(--sg-text)]"
            >
              <Settings className="mr-2 h-4 w-4 text-[var(--sg-text-muted)]" />
              Settings
            </DropdownMenuItem>

            {/* Sign Out - only show for OAuth users */}
            {user?.type === "user" && (
              <>
                <DropdownMenuSeparator className="bg-[var(--sg-border)]" />
                <DropdownMenuItem
                  onClick={logout}
                  className="cursor-pointer text-[var(--sg-error)] focus:bg-[var(--sg-error)]/10 focus:text-[var(--sg-error)]"
                >
                  <LogOut className="mr-2 h-4 w-4" />
                  Sign out
                </DropdownMenuItem>
              </>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}
