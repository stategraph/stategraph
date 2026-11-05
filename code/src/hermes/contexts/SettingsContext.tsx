"use client";

import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useMemo,
  ReactNode,
} from "react";

// ============================================================================
// Settings Interface
// ============================================================================

export interface UserSettings {
  // Data Display
  itemsPerPage: number; // Default items per page in tables
  timezone: "local" | "utc"; // Timezone preference for timestamps

  // UI Preferences
  compactMode: boolean; // Denser UI layout
  showDebugInfo: boolean; // Show debug information

  // Safety
  confirmDangerousActions: boolean; // Require confirmation for destructive operations
}

export interface SettingsContextValue {
  settings: UserSettings;
  updateSetting: <K extends keyof UserSettings>(
    key: K,
    value: UserSettings[K]
  ) => void;
  resetSettings: () => void;
}

const SettingsContext = createContext<SettingsContextValue | undefined>(
  undefined
);

// ============================================================================
// Default Settings
// ============================================================================

const DEFAULT_SETTINGS: UserSettings = {
  itemsPerPage: 50,
  timezone: "local",
  compactMode: false,
  showDebugInfo: false,
  confirmDangerousActions: true,
};

const STORAGE_KEY = "stategraph-settings";

// ============================================================================
// Provider Component
// ============================================================================

interface SettingsProviderProps {
  children: ReactNode;
}

export function SettingsProvider({ children }: SettingsProviderProps) {
  const [mounted, setMounted] = useState(false);

  // Initialize settings from localStorage using lazy initialization
  const [settings, setSettings] = useState<UserSettings>(() => {
    if (typeof window === "undefined") return DEFAULT_SETTINGS;
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored) as Partial<UserSettings>;
        // Merge with defaults to handle new settings added over time
        return { ...DEFAULT_SETTINGS, ...parsed };
      }
    } catch (error) {
      console.error("[SettingsContext] Failed to load settings:", error);
    }
    return DEFAULT_SETTINGS;
  });

  // Set mounted flag after first render
  useEffect(() => {
    setTimeout(() => setMounted(true), 0);
  }, []);

  // Persist settings to localStorage whenever they change
  useEffect(() => {
    if (!mounted) return; // Don't persist on initial mount

    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
    } catch (error) {
      console.error("[SettingsContext] Failed to save settings:", error);
    }
  }, [settings, mounted]);

  const updateSetting = <K extends keyof UserSettings>(
    key: K,
    value: UserSettings[K]
  ) => {
    setSettings((prev) => ({ ...prev, [key]: value }));
  };

  const resetSettings = () => {
    setSettings(DEFAULT_SETTINGS);
  };

  const value = useMemo(
    () => ({
      settings,
      updateSetting,
      resetSettings,
    }),
    [settings]
  );

  return (
    <SettingsContext.Provider value={value}>
      {children}
    </SettingsContext.Provider>
  );
}

// ============================================================================
// Hook
// ============================================================================

export function useSettings(): SettingsContextValue {
  const context = useContext(SettingsContext);

  if (context === undefined) {
    throw new Error("useSettings must be used within a SettingsProvider");
  }

  return context;
}
