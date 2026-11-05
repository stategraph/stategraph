'use client';

import { Suspense } from 'react';
import { PageHeader, PageSection, PageSurface } from '@/components/page';
import { CreateUserDialog, UsersTable } from '@/components/users';
import { useAuth } from '@/components/auth/AuthProvider';
import { isInstanceAdmin } from '@/lib/api/capabilities';

function UsersPageClient() {
  const { user } = useAuth();

  // Only admins can access user management
  if (!isInstanceAdmin(user?.capabilities)) {
    return (
      <div className="flex flex-col items-center justify-center h-full">
        <h1 className="text-2xl font-bold mb-2 text-[var(--sg-text)]">Access Denied</h1>
        <p className="text-[var(--sg-text-muted)]">Admin privileges required to manage users.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col w-full">
      <PageHeader
        title="User Management"
        subtitle="Manage users, roles, and permissions"
      />

      <PageSection title="Users" actions={<CreateUserDialog />}>
        <PageSurface>
          <UsersTable />
        </PageSurface>
      </PageSection>
    </div>
  );
}

export default function UsersPage() {
  return (
    <Suspense fallback={<div className="p-6">Loading...</div>}>
      <UsersPageClient />
    </Suspense>
  );
}
