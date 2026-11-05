'use client';

import { useState, useEffect, type KeyboardEvent as ReactKeyboardEvent } from 'react';
import { listUsers, type UsersListResponse } from '@/lib/api/client';
import { useUrlSyncedNullable } from '@/hooks';
import { ChangePasswordDialog } from './ChangePasswordDialog';
import { DeleteUserDialog } from './DeleteUserDialog';
import { EditUserDialog } from './EditUserDialog';
import { SetInstanceAdminDialog } from './SetInstanceAdminDialog';
import { UserDetailCard } from './UserDetailCard';
import { adminScopeOf, roleLabel, setInstanceAdminLabel, type AdminScope } from './adminScope';
import { Avatar } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { SearchInput } from '@/components/ui/search-input';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { MoreHorizontal, Shield, ShieldOff, Key, Trash2, Edit } from 'lucide-react';
import { useAuth } from '@/components/auth/AuthProvider';
import { AdminRightsNotice, type AdminRightsChange } from '@/components/settings/AdminRightsNotice';
import { isInstanceAdmin } from '@/lib/api/capabilities';

/** Query parameter holding the user whose details box is open (#2665). */
const USER_PARAM = 'user';

export function UsersTable() {
  const { user: currentUser } = useAuth();
  // Set only after an installation-admin grant or removal succeeds: advice on the API keys the
  // change does not reach, not permanent policy guidance.
  const [rightsNotice, setRightsNotice] =
    useState<Extract<AdminRightsChange, 'granted' | 'revoked'> | null>(null);
  const [users, setUsers] = useState<UsersListResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters
  const [search, setSearch] = useState('');
  const [typeFilter, setTypeFilter] = useState<string>('all');
  const [cursor, setCursor] = useState<string | undefined>(undefined);
  const [limit, setLimit] = useState(25);

  // The picked user, in the URL so the open details box survives a copy into a
  // new tab. Picking an entry opens the box below the list; picking it again
  // closes it.
  const [selectedUserId, setSelectedUserId] = useUrlSyncedNullable(USER_PARAM);

  const toggleUser = (id: string) => {
    setSelectedUserId(selectedUserId === id ? null : id);
  };

  const onRowKeyDown = (e: ReactKeyboardEvent, id: string) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleUser(id);
    }
  };

  // Dialog states
  const [editingUser, setEditingUser] = useState<string | null>(null);
  const [deletingUser, setDeletingUser] = useState<string | null>(null);
  const [changingPasswordUser, setChangingPasswordUser] = useState<string | null>(null);
  const [instanceAdminUser, setInstanceAdminUser] = useState<{ id: string; scope: AdminScope } | null>(null);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await listUsers({
        type: typeFilter === 'all' ? undefined : typeFilter,
        search: search || undefined,
        cursor,
        limit,
      });
      // Filter out system users (HAL) and API service accounts (managed in API Keys tab)
      const filteredUsers = response.users.filter(user => user.type !== 'system' && user.type !== 'api');
      setUsers({
        ...response,
        users: filteredUsers,
        total_count: filteredUsers.length,
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search, typeFilter, cursor, limit]);

  const handleRefresh = () => {
    fetchUsers();
  };

  if (loading && !users) {
    return <div className="p-6 text-center">Loading users...</div>;
  }

  if (error) {
    return (
      <div className="p-6 text-center text-red-600">
        Error: {error}
        <Button onClick={handleRefresh} className="ml-4" variant="outline" size="sm">
          Retry
        </Button>
      </div>
    );
  }

  const renderUserActions = (user: UsersListResponse['users'][number]) => {
    const scope = adminScopeOf(user);
    // Granting is offered to anyone without the installation-wide grant, a tenant admin included;
    // revoking only on an installation-wide one that is not the caller's own. Revoking a tenant-scoped
    // grant is done from the tenant's members screen.
    const offersSetInstanceAdmin = scope !== 'instance' || user.id !== currentUser?.id;
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            aria-label={`Manage ${user.name}`}
            title="Manage this user"
          >
            Manage
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => setEditingUser(user.id)}>
            <Edit className="mr-2 h-4 w-4" />
            Edit
          </DropdownMenuItem>
          {!user.auth_origin && (
            <DropdownMenuItem onClick={() => setChangingPasswordUser(user.id)}>
              <Key className="mr-2 h-4 w-4" />
              Change Password
            </DropdownMenuItem>
          )}
          {offersSetInstanceAdmin && (
            <DropdownMenuItem onClick={() => setInstanceAdminUser({ id: user.id, scope })}>
              {scope === 'instance' ? (
                <ShieldOff className="mr-2 h-4 w-4" />
              ) : (
                <Shield className="mr-2 h-4 w-4" />
              )}
              {setInstanceAdminLabel(scope)}
            </DropdownMenuItem>
          )}
          {user.id !== currentUser?.id && (
            <DropdownMenuItem
              onClick={() => setDeletingUser(user.id)}
              variant="destructive"
            >
              <Trash2 className="mr-2 h-4 w-4" />
              Delete
            </DropdownMenuItem>
          )}
        </DropdownMenuContent>
      </DropdownMenu>
    );
  };

  return (
    <div className="space-y-4">
      {rightsNotice && (
        <AdminRightsNotice
          change={rightsNotice}
          canRevokeAnyKeys={isInstanceAdmin(currentUser?.capabilities)}
          onDismiss={() => setRightsNotice(null)}
        />
      )}
      {/* Filters */}
      <div className="flex flex-col sm:flex-row sm:items-center gap-4">
        <SearchInput
          placeholder="Search by name or email..."
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setCursor(undefined);
          }}
        />

        <div className="grid grid-cols-2 gap-3 sm:flex sm:gap-4">
        <Select
          value={typeFilter}
          onValueChange={(value) => {
            setTypeFilter(value);
            setCursor(undefined);
          }}
        >
          <SelectTrigger className="w-full sm:w-[180px]" style={{ background: 'var(--sg-bg-2)', borderColor: 'var(--sg-border)' }}>
            <SelectValue placeholder="Filter by type" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All Types</SelectItem>
            <SelectItem value="user">User</SelectItem>
          </SelectContent>
        </Select>

        <Select
          value={limit.toString()}
          onValueChange={(value) => {
            setLimit(parseInt(value));
            setCursor(undefined);
          }}
        >
          <SelectTrigger className="w-full sm:w-[120px]" style={{ background: 'var(--sg-bg-2)', borderColor: 'var(--sg-border)' }}>
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="25">25 per page</SelectItem>
            <SelectItem value="50">50 per page</SelectItem>
            <SelectItem value="100">100 per page</SelectItem>
          </SelectContent>
        </Select>
        </div>
      </div>

      {/* The list and, beside it on large screens, the details of the picked
          user (#2665): a box below a long list is out of reach without scrolling. */}
      <div className="flex flex-col lg:flex-row gap-4">
        <div className="flex-1 min-w-0 space-y-4">
          {/* Table (desktop) */}
          <div className="hidden lg:block border rounded-lg overflow-hidden" style={{ borderColor: 'var(--sg-border)' }}>
            <table className="w-full">
              <thead style={{ backgroundColor: 'var(--sg-bg-0)', borderBottom: '1px solid var(--sg-border)' }}>
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Name</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Email</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>User ID</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Type</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Auth</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Role</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Created</th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users?.users.map((user, index) => (
                  <tr
                    key={user.id}
                    onClick={() => toggleUser(user.id)}
                    onKeyDown={(e) => onRowKeyDown(e, user.id)}
                    tabIndex={0}
                    role="button"
                    aria-pressed={selectedUserId === user.id}
                    className={`cursor-pointer transition-colors ${
                      selectedUserId === user.id
                        ? 'bg-[var(--sg-accent-bg)]'
                        : 'hover:bg-[var(--sg-bg-0)]'
                    }`}
                    style={{ borderTop: index > 0 ? '1px solid var(--sg-border)' : undefined }}
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        <Avatar user={user} size={32} />
                        <span className="font-medium" style={{ color: 'var(--sg-text)' }}>{user.name}</span>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>{user.email || '-'}</td>
                    <td className="px-4 py-3 text-xs font-mono" style={{ color: 'var(--sg-text-dim)' }}>{user.id}</td>
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: 'var(--sg-bg-0)', color: 'var(--sg-text)' }}>
                        {user.type}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                      {user.auth_origin || 'password'}
                    </td>
                    <td className="px-4 py-3">
                      {adminScopeOf(user) !== 'none' ? (
                        <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: 'var(--sg-accent-bg)', color: 'var(--sg-accent)' }}>
                          <Shield className="w-3 h-3" />
                          {roleLabel(adminScopeOf(user))}
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: 'var(--sg-bg-0)', color: 'var(--sg-text-muted)' }}>
                          {roleLabel(adminScopeOf(user))}
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                      {new Date(user.created_at).toLocaleDateString()}
                    </td>
                      <td className="px-4 py-3 text-right" onClick={(e) => e.stopPropagation()}>
                        {renderUserActions(user)}
                      </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Cards (mobile / tablet) */}
          <div className="lg:hidden space-y-3">
            {users?.users.map((user) => (
              <div
                key={user.id}
                onClick={() => toggleUser(user.id)}
                onKeyDown={(e) => onRowKeyDown(e, user.id)}
                tabIndex={0}
                role="button"
                aria-pressed={selectedUserId === user.id}
                className={`rounded-lg border p-3 space-y-2 cursor-pointer transition-colors ${
                  selectedUserId === user.id
                    ? 'border-[var(--sg-accent)] bg-[var(--sg-accent-bg)]'
                    : 'border-[var(--sg-border)] bg-[var(--sg-bg-1)] hover:bg-[var(--sg-bg-2)]'
                }`}
              >
                <div className="flex items-start justify-between gap-2">
                  <div className="flex items-center gap-2 min-w-0">
                    <Avatar user={user} size={32} />
                    <span className="font-medium truncate" style={{ color: 'var(--sg-text)' }}>
                      {user.name}
                    </span>
                  </div>
                  <div onClick={(e) => e.stopPropagation()}>
                    {renderUserActions(user)}
                  </div>
                </div>
                {user.email && (
                  <div className="text-sm break-all" style={{ color: 'var(--sg-text-muted)' }}>
                    {user.email}
                  </div>
                )}
                <div className="flex flex-wrap items-center gap-2">
                  {adminScopeOf(user) !== 'none' ? (
                    <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: 'var(--sg-accent-bg)', color: 'var(--sg-accent)' }}>
                      <Shield className="w-3 h-3" />
                      {roleLabel(adminScopeOf(user))}
                    </span>
                  ) : (
                    <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: 'var(--sg-bg-0)', color: 'var(--sg-text-muted)' }}>
                      {roleLabel(adminScopeOf(user))}
                    </span>
                  )}
                  <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium" style={{ backgroundColor: 'var(--sg-bg-0)', color: 'var(--sg-text)' }}>
                    {user.type}
                  </span>
                  <span className="text-xs" style={{ color: 'var(--sg-text-muted)' }}>
                    {user.auth_origin || 'password'}
                  </span>
                </div>
                <div className="text-xs" style={{ color: 'var(--sg-text-muted)' }}>
                  Created {new Date(user.created_at).toLocaleDateString()}
                </div>
                <div className="text-xs font-mono break-all" style={{ color: 'var(--sg-text-dim)' }}>
                  {user.id}
                </div>
              </div>
            ))}
          </div>

          {/* Pagination */}
          {(cursor || users?.has_more) && (
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                Showing {users?.users.length || 0} users
                {users?.has_more && ' (more available)'}
              </div>
              <div className="flex gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setCursor(undefined)}
                  disabled={!cursor}
                >
                  First Page
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setCursor(users?.next_cursor)}
                  disabled={!users?.has_more}
                >
                  Next
                </Button>
              </div>
            </div>
          )}
        </div>
        {selectedUserId && (
          <UserDetailCard userId={selectedUserId} onClose={() => setSelectedUserId(null)} />
        )}
      </div>

      {/* Dialogs */}
      {editingUser && (
        <EditUserDialog
          userId={editingUser}
          onClose={() => setEditingUser(null)}
          onSuccess={handleRefresh}
        />
      )}
      {deletingUser && (
        <DeleteUserDialog
          userId={deletingUser}
          onClose={() => setDeletingUser(null)}
          onSuccess={handleRefresh}
        />
      )}
      {changingPasswordUser && (
        <ChangePasswordDialog
          userId={changingPasswordUser}
          onClose={() => setChangingPasswordUser(null)}
          onSuccess={handleRefresh}
        />
      )}
      {instanceAdminUser && (
        <SetInstanceAdminDialog
          userId={instanceAdminUser.id}
          scope={instanceAdminUser.scope}
          onClose={() => setInstanceAdminUser(null)}
          onSuccess={() => {
            handleRefresh();
            setRightsNotice(instanceAdminUser.scope !== 'instance' ? 'granted' : 'revoked');
          }}
        />
      )}
    </div>
  );
}
