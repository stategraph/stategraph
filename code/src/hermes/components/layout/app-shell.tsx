"use client";

import { useEffect, useState } from "react";
import { usePathname } from "next/navigation";
import { TopBar } from "./top-bar";
import { Sidebar } from "./sidebar";
import { UpdateBanner } from "./update-banner";
import { InspectorPanel } from "@/components/inspector/InspectorPanel";
import { StateAreaGate } from "@/components/product/StateAreaGate";

interface AppShellProps {
  children: React.ReactNode;
}

export function AppShell({ children }: AppShellProps) {
  // Mobile/tablet nav drawer state. On lg+ the sidebar is always visible and
  // this state is ignored (the sidebar renders statically).
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const pathname = usePathname();

  // Close the drawer whenever the route changes (e.g. after tapping a nav link).
  // React's "adjust state during render" pattern (no effect, no ref) avoids the
  // cascading re-render that calling setState inside an effect would cause.
  const [lastPathname, setLastPathname] = useState(pathname);
  if (pathname !== lastPathname) {
    setLastPathname(pathname);
    setSidebarOpen(false);
  }

  // Lock body scroll and allow Escape to close while the drawer is open.
  useEffect(() => {
    if (!sidebarOpen) return;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setSidebarOpen(false);
    };
    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", handleKeyDown);
    };
  }, [sidebarOpen]);

  return (
    <div className="flex min-h-screen bg-[var(--sg-bg-0)]">
      {/* Drawer backdrop — only on mobile/tablet while open */}
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/50 lg:hidden"
          onClick={() => setSidebarOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* Left Sidebar — static on lg+, off-canvas drawer below lg */}
      <Sidebar open={sidebarOpen} onClose={() => setSidebarOpen(false)} />

      {/* Main Content Area */}
      <div className="flex flex-1 flex-col min-w-0">
        {/* Banners */}
        <UpdateBanner />

        {/* Top Bar */}
        <TopBar onMenuClick={() => setSidebarOpen(true)} />

        {/* Main Content + Inspector Panel */}
        <div className="flex flex-1 overflow-hidden">
          {/* Main Content */}
          <main className="flex-1 overflow-auto p-4 sm:p-6 min-w-0">
            <StateAreaGate>{children}</StateAreaGate>
          </main>

          {/* Inspector Panel - Conditionally rendered based on context */}
          <InspectorPanel />
        </div>
      </div>
    </div>
  );
}
