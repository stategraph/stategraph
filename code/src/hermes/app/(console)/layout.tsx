import { AppShell } from "@/components/layout";
import { InspectorProvider } from "@/components/inspector/InspectorContext";
import { TenantNamingProvider } from "@/components/tenant/TenantNamePrompt";
import { AuthProvider } from "@/components/auth";
import {
  TenantProvider,
  StateProvider,
  SettingsProvider,
  VersionProvider,
  LicenseProvider,
  SetupProgressProvider,
} from "@/contexts";

export default function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <SettingsProvider>
      <AuthProvider>
        <LicenseProvider>
          <VersionProvider>
            <TenantProvider>
              <StateProvider>
                <SetupProgressProvider>
                  <InspectorProvider>
                    <TenantNamingProvider>
                      <AppShell>{children}</AppShell>
                    </TenantNamingProvider>
                  </InspectorProvider>
                </SetupProgressProvider>
              </StateProvider>
            </TenantProvider>
          </VersionProvider>
        </LicenseProvider>
      </AuthProvider>
    </SettingsProvider>
  );
}
