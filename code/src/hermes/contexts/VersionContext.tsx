"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from "react";
import {
  getServerVersion,
  getLatestGitHubRelease,
  type GitHubRelease,
} from "@/lib/api/client";
import { isVersionOlder, isValidSemver } from "@/lib/utils/version";

const GITHUB_CACHE_KEY = "stategraph-github-release-cache";
const CACHE_DURATION_MS = 60 * 60 * 1000; // 1 hour

interface CachedRelease {
  release: GitHubRelease | null;
  fetchedAt: number;
}

export interface VersionContextValue {
  /** Current server version (e.g., "1.0.0", "dev") */
  currentVersion: string | null;
  /** Latest GitHub release info */
  latestRelease: GitHubRelease | null;
  /** Whether an update is available */
  updateAvailable: boolean;
  /** Whether version data is loading */
  isLoading: boolean;
  /** Error message if fetching failed */
  error: string | null;
  /** Timestamp of last check */
  lastChecked: number | null;
  /** Manually refresh version info */
  refresh: () => Promise<void>;
}

const VersionContext = createContext<VersionContextValue | undefined>(undefined);

function loadCachedRelease(): CachedRelease | null {
  if (typeof window === "undefined") return null;

  try {
    const cached = localStorage.getItem(GITHUB_CACHE_KEY);
    if (!cached) return null;

    const parsed = JSON.parse(cached) as CachedRelease;
    const now = Date.now();

    // Check if cache is still valid
    if (now - parsed.fetchedAt < CACHE_DURATION_MS) {
      return parsed;
    }

    // Cache expired
    localStorage.removeItem(GITHUB_CACHE_KEY);
    return null;
  } catch {
    localStorage.removeItem(GITHUB_CACHE_KEY);
    return null;
  }
}

function saveCachedRelease(release: GitHubRelease | null): void {
  if (typeof window === "undefined") return;

  const cached: CachedRelease = {
    release,
    fetchedAt: Date.now(),
  };
  localStorage.setItem(GITHUB_CACHE_KEY, JSON.stringify(cached));
}

export function VersionProvider({ children }: { children: ReactNode }) {
  const [currentVersion, setCurrentVersion] = useState<string | null>(null);
  const [latestRelease, setLatestRelease] = useState<GitHubRelease | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [lastChecked, setLastChecked] = useState<number | null>(null);

  const fetchVersionData = useCallback(async (forceRefresh = false) => {
    setIsLoading(true);
    setError(null);

    try {
      // Fetch server version
      const versionResponse = await getServerVersion();
      setCurrentVersion(versionResponse.version);

      // Check cache for GitHub release (unless force refresh)
      if (!forceRefresh) {
        const cached = loadCachedRelease();
        if (cached) {
          setLatestRelease(cached.release);
          setLastChecked(cached.fetchedAt);
          setIsLoading(false);
          return;
        }
      }

      // Fetch from GitHub
      const release = await getLatestGitHubRelease();
      setLatestRelease(release);
      saveCachedRelease(release);
      setLastChecked(Date.now());
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to fetch version info");
    } finally {
      setIsLoading(false);
    }
  }, []);

  const refresh = useCallback(async () => {
    await fetchVersionData(true);
  }, [fetchVersionData]);

  // Initial fetch
  useEffect(() => {
    fetchVersionData();
  }, [fetchVersionData]);

  // Calculate if update is available
  const updateAvailable =
    currentVersion !== null &&
    latestRelease !== null &&
    isValidSemver(currentVersion) &&
    isVersionOlder(currentVersion, latestRelease.tag_name);

  const value: VersionContextValue = {
    currentVersion,
    latestRelease,
    updateAvailable,
    isLoading,
    error,
    lastChecked,
    refresh,
  };

  return (
    <VersionContext.Provider value={value}>{children}</VersionContext.Provider>
  );
}

export function useVersion(): VersionContextValue {
  const context = useContext(VersionContext);
  if (context === undefined) {
    throw new Error("useVersion must be used within a VersionProvider");
  }
  return context;
}
