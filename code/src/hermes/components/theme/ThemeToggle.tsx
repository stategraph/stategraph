"use client";

import { useTheme } from "@/contexts/ThemeContext";
import { Moon, Sun } from "lucide-react";

/**
 * ThemeToggle - Minimal theme switcher for light/dark mode
 *
 * Cycles through: light → dark → system → light
 */
export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  const handleToggle = () => {
    const nextTheme = theme === "light" ? "dark" : theme === "dark" ? "system" : "light";
    setTheme(nextTheme);
  };

  // Display icon based on current theme setting
  const Icon = theme === "dark" ? Moon : Sun;
  const label = theme === "light" ? "Light mode" : theme === "dark" ? "Dark mode" : "System theme";

  return (
    <button
      type="button"
      onClick={handleToggle}
      aria-label={`Current theme: ${label}. Click to change.`}
      title={label}
      className="
        flex items-center justify-center
        h-9 w-9
        rounded-[var(--sg-button-radius)]
        text-[var(--sg-text-muted)]
        hover:text-[var(--sg-text)]
        hover:bg-[var(--sg-bg-2)]
        transition-colors duration-200
        focus-visible:outline-none
        focus-visible:ring-2
        focus-visible:ring-[var(--sg-accent)]
      "
    >
      <Icon className="h-4 w-4" />
    </button>
  );
}
