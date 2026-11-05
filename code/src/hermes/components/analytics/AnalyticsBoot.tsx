"use client";

import { useEffect } from "react";
import { getSetupStatus } from "@/lib/api/client";
import { startAnalytics } from "@/lib/analytics";

/** Starts or disables product analytics once per page load, from the server mode. */
export function AnalyticsBoot() {
  useEffect(() => {
    getSetupStatus().then(
      (status) => startAnalytics(status.mode),
      () => startAnalytics(undefined)
    );
  }, []);
  return null;
}
