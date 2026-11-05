"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useMemo,
  useCallback,
  type ReactNode,
} from "react";
import {
  getLicenseStatus,
  getSetupStatus,
  type LicenseStatusResponse,
  type SetupStatusResponse,
} from "@/lib/api/client";

/** Operational mode the server was started in; undefined in default mode,
 *  and until the setup status has loaded. */
export type Mode = "COMMUNISM";

/** The schema leaves `mode` a plain string: an unknown value reads as the
 *  default mode. */
function parseMode(raw: SetupStatusResponse["mode"]): Mode | undefined {
  return raw === "COMMUNISM" ? raw : undefined;
}

/** Where the license comes from; undefined until the status has loaded. */
export type LicenseSource = LicenseStatusResponse["source"];

export interface LicenseContextValue {
  isLoading: boolean;
  licensed: boolean;
  /** Whether this edition of the server needs a license at all. No license UI
   *  applies when false, whatever `licensed` says. */
  required: boolean;
  source: LicenseSource | undefined;
  mode: Mode | undefined;
  refresh: () => Promise<void>;
}

const LicenseContext = createContext<LicenseContextValue | undefined>(undefined);

export function LicenseProvider({ children }: { children: ReactNode }) {
  const [license, setLicense] = useState<LicenseStatusResponse | null>(null);
  const [mode, setMode] = useState<Mode | undefined>(undefined);
  const [isLoading, setIsLoading] = useState(true);

  const refresh = useCallback(async () => {
    const [licenseStatus, setup] = await Promise.all([
      getLicenseStatus().catch(() => null),
      getSetupStatus().catch(() => null),
    ]);
    setLicense(licenseStatus);
    setMode(parseMode(setup?.mode));
  }, []);

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        await refresh();
      } finally {
        if (active) {
          setIsLoading(false);
        }
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [refresh]);

  const value = useMemo(() => {
    const licensed = license?.licensed === true;
    const source = license?.source;
    const required = license?.required !== false;

    return { isLoading, licensed, required, source, mode, refresh };
  }, [license, isLoading, mode, refresh]);

  return (
    <LicenseContext.Provider value={value}>{children}</LicenseContext.Provider>
  );
}

export function useLicense(): LicenseContextValue {
  const context = useContext(LicenseContext);
  if (context === undefined) {
    throw new Error("useLicense must be used within LicenseProvider");
  }
  return context;
}
