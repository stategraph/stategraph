'use client';

import { useCallback, useEffect, useState, type KeyboardEvent as ReactKeyboardEvent } from 'react';
import {
  InvitationCreateResponse,
  TenantInvitation,
  TenantMember,
  listTenantInvitations,
  addTenantMember,
  listTenantMembers,
  reissueTenantInvitation,
  removeTenantMember,
  revokeTenantInvitation,
  setTenantMemberRole,
} from '@/lib/api/client';
import { AdminRightsNotice, type AdminRightsChange } from '@/components/settings/AdminRightsNotice';
import { Avatar } from '@/components/ui/avatar';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { DismissibleBanner } from '@/components/ui/dismissible-banner';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { Timestamp } from '@/components/ui/timestamp';
import { Check, Copy, MoreHorizontal, RefreshCw, Shield, ShieldOff, UserX, XCircle } from 'lucide-react';
import { useUrlSyncedNullable } from '@/hooks';
import { UserDetailCard } from '@/components/users';
import { InviteMemberDialog } from './InviteMemberDialog';
import { invitationLinkMessage } from './invitation-copy';
import { track } from '@/lib/analytics';

/** Query parameter holding the member whose details box is open (#2665). */
const USER_PARAM = 'user';

/**
 * Tenant membership management: the members of one tenant and its invitations,
 * driven by the tenant-scoped endpoints
 * (`Sgs_user_session.Caps.manages_tenant_member` on the server — tenant admin
 * or tenant users-manage; NOT installation admin).
 *
 * A member whose grant covers more than this tenant (`admin_scope`/`users_manage_scope`
 * = "wider") cannot be edited from here: the server refuses it and the controls
 * are disabled with an explanation, per the API's own guidance.
 */
export function MembersPanel({
  tenantId,
  currentUserId,
  canGrantAdmin,
  canRevokeAnyKeys,
}: {
  tenantId: string;
  currentUserId: string | undefined;
  /**
   * Whether the viewer administers this tenant. Managing members is the narrower grant: it does not
   * carry the right to hand out tenant administrator, and the server refuses that with 403. So the
   * promote controls are hidden for a member-manager, while everything else the grant is for --
   * inviting, removing, toggling member management, and demoting -- stays available.
   */
  canGrantAdmin: boolean;
  /**
   * Whether the viewer may revoke any user's API keys, which only an installation admin may. It
   * decides whether the notice after an access-rights change links to the keys list or asks to
   * involve an installation admin.
   */
  canRevokeAnyKeys: boolean;
}) {
  // Set only after an access-rights mutation succeeds: advice on the API keys the change does not
  // reach, not permanent policy guidance. Cleared when the next member action starts.
  const [rightsNotice, setRightsNotice] = useState<AdminRightsChange | null>(null);
  const [members, setMembers] = useState<TenantMember[] | null>(null);
  const [invitations, setInvitations] = useState<TenantInvitation[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  // The tone distinguishes the two success outcomes of an add: `created` is a change the operator
  // made, `noop` is a correction of their expectation -- worth a different colour, not an error.
  const [actionNotice, setActionNotice] = useState<{
    text: string;
    tone: 'created' | 'noop';
  } | null>(null);
  const [busyUserId, setBusyUserId] = useState<string | null>(null);
  const [removing, setRemoving] = useState<TenantMember | null>(null);
  // The accept link is returned only once (the server keeps the token's hash),
  // so it is held here and shown until dismissed, surviving the invite dialog.
  const [inviteLink, setInviteLink] = useState<InvitationCreateResponse | null>(null);
  // Add an existing user (with an account) directly, as opposed to inviting someone new.
  const [addUserId, setAddUserId] = useState('');
  const [adding, setAdding] = useState(false);
  const [copied, setCopied] = useState(false);
  // The picked member, in the URL so the open details box survives a copy into a
  // new tab. Picking an entry opens the box below the list; picking it again
  // closes it.
  const [selectedUserId, setSelectedUserId] = useUrlSyncedNullable(USER_PARAM);

  const toggleUser = (userId: string) => {
    setSelectedUserId(selectedUserId === userId ? null : userId);
  };

  const onRowKeyDown = (e: ReactKeyboardEvent, userId: string) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggleUser(userId);
    }
  };

  const refresh = useCallback(async () => {
    setError(null);
    try {
      const [membersPage, invitationsPage] = await Promise.all([
        listTenantMembers(tenantId, { limit: 100 }),
        listTenantInvitations(tenantId, { limit: 100 }),
      ]);
      setMembers(membersPage.members);
      setInvitations(invitationsPage.invitations);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load members');
    } finally {
      setLoading(false);
    }
  }, [tenantId]);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const runAction = async (
    userId: string,
    action: () => Promise<unknown>,
    event: string,
    props?: Record<string, unknown>,
    onSuccess?: () => void
  ) => {
    setActionError(null);
    setActionNotice(null);
    setRightsNotice(null);
    setBusyUserId(userId);
    try {
      await action();
      onSuccess?.();
      track(event, props);
      await refresh();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Action failed');
    } finally {
      setBusyUserId(null);
    }
  };

  const copyLink = async (url: string) => {
    await navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const addMember = async () => {
    const id = addUserId.trim();
    if (!id) return;
    setActionError(null);
    setActionNotice(null);
    setRightsNotice(null);
    setAdding(true);
    try {
      const { member: added, created } = await addTenantMember(tenantId, id);
      track('member_added', { created });
      setAddUserId('');
      await refresh();
      // The listing is oldest-membership-first and `refresh` reads only its first page, so a member
      // added moments ago is on the last page -- invisible here on any tenant past `limit`. The
      // endpoint returns the member it added, so show that rather than making the operator hunt for
      // it. Guarded because a small tenant's first page already contains them, and a repeat add
      // (which succeeds, idempotently) must not double the row.
      setMembers((current) =>
        current === null || current.some((m) => m.user_id === added.user_id)
          ? current
          : [...current, added]
      );
      // 201 means this call made the membership, 200 that it was already there. The listing cannot
      // answer that question -- see `addTenantMember` -- so the status is the only honest source.
      setActionNotice(
        created
          ? { text: `${added.name} was added to this tenant.`, tone: 'created' }
          : { text: `${added.name} was already a member of this tenant.`, tone: 'noop' }
      );
    } catch (err) {
      setActionError(err instanceof Error ? err.message : 'Failed to add member');
    } finally {
      setAdding(false);
    }
  };

  if (loading && !members) {
    return <div className="p-6 text-center">Loading members...</div>;
  }

  if (error) {
    return (
      <div className="p-6 text-center text-red-600">
        Error: {error}
        <Button onClick={refresh} className="ml-4" variant="outline" size="sm">
          Retry
        </Button>
      </div>
    );
  }

  const renderRole = (member: TenantMember) => (
    <div className="flex flex-wrap items-center gap-1">
      {member.admin_scope !== 'none' && (
        <Badge>{member.admin_scope === 'wider' ? 'Admin (installation-wide)' : 'Admin (tenant)'}</Badge>
      )}
      {member.admin_scope === 'none' && member.users_manage_scope !== 'none' && (
        <Badge variant="secondary">
          {member.users_manage_scope === 'wider'
            ? 'Manages members (installation-wide)'
            : 'Manages members (tenant)'}
        </Badge>
      )}
      {member.admin_scope === 'none' && member.users_manage_scope === 'none' && (
        <Badge variant="outline">Member</Badge>
      )}
    </div>
  );

  const renderMemberActions = (member: TenantMember) => {
    const isSelf = currentUserId != null && member.user_id === currentUserId;
    const adminWider = member.admin_scope === 'wider';
    const manageWider = member.users_manage_scope === 'wider';
    const widerHint = 'This grant is installation-wide and cannot be changed from here';
    return (
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            aria-label={`Manage ${member.name}`}
            title="Manage this member"
            disabled={busyUserId === member.user_id}
          >
            Manage
            <MoreHorizontal className="h-4 w-4" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {member.admin_scope === 'none' ? (
            canGrantAdmin && (
              <DropdownMenuItem
                onClick={() =>
                  runAction(member.user_id, () =>
                    setTenantMemberRole(tenantId, member.user_id, { tenant_admin: true }),
                    'member_role_changed',
                    { change: 'tenant_admin', value: true },
                    () => setRightsNotice('granted')
                  )
                }
              >
                <Shield className="mr-2 h-4 w-4" />
                Make tenant admin
              </DropdownMenuItem>
            )
          ) : (
            <DropdownMenuItem
              disabled={adminWider || isSelf}
              title={adminWider ? widerHint : isSelf ? 'You cannot revoke your own admin' : undefined}
              onClick={() =>
                runAction(member.user_id, () =>
                  setTenantMemberRole(tenantId, member.user_id, { tenant_admin: false }),
                  'member_role_changed',
                  { change: 'tenant_admin', value: false },
                  () => setRightsNotice('revoked')
                )
              }
            >
              <ShieldOff className="mr-2 h-4 w-4" />
              Remove tenant admin
            </DropdownMenuItem>
          )}
          {member.users_manage_scope === 'none' ? (
            <DropdownMenuItem
              onClick={() =>
                runAction(member.user_id, () =>
                  setTenantMemberRole(tenantId, member.user_id, { can_manage_users: true }),
                  'member_role_changed',
                  { change: 'can_manage_users', value: true },
                  () => setRightsNotice('granted')
                )
              }
            >
              <Shield className="mr-2 h-4 w-4" />
              Allow managing members
            </DropdownMenuItem>
          ) : (
            <DropdownMenuItem
              disabled={manageWider}
              title={manageWider ? widerHint : undefined}
              onClick={() =>
                runAction(member.user_id, () =>
                  setTenantMemberRole(tenantId, member.user_id, { can_manage_users: false }),
                  'member_role_changed',
                  { change: 'can_manage_users', value: false },
                  () => setRightsNotice('revoked')
                )
              }
            >
              <ShieldOff className="mr-2 h-4 w-4" />
              Disallow managing members
            </DropdownMenuItem>
          )}
          <DropdownMenuItem
            disabled={adminWider || isSelf}
            title={adminWider ? widerHint : isSelf ? 'You cannot remove yourself' : undefined}
            className="text-red-500"
            onClick={() => setRemoving(member)}
          >
            <UserX className="mr-2 h-4 w-4" />
            Remove from tenant
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    );
  };

  const invitationStatusBadge = (invitation: TenantInvitation) => {
    switch (invitation.status) {
      case 'pending':
        return <Badge>Pending</Badge>;
      case 'accepted':
        return <Badge variant="secondary">Accepted</Badge>;
      case 'revoked':
        return <Badge variant="outline">Revoked</Badge>;
      case 'expired':
        return <Badge variant="outline">Expired</Badge>;
    }
  };

  return (
    <div className="space-y-6">
      {actionError && (
        <DismissibleBanner tone="error" onDismiss={() => setActionError(null)}>
          {actionError}
        </DismissibleBanner>
      )}

      {actionNotice && (
        <DismissibleBanner
          tone={actionNotice.tone === 'created' ? 'success' : 'warning'}
          onDismiss={() => setActionNotice(null)}
        >
          {actionNotice.text}
        </DismissibleBanner>
      )}

      {rightsNotice && (
        <AdminRightsNotice
          change={rightsNotice}
          canRevokeAnyKeys={canRevokeAnyKeys}
          onDismiss={() => setRightsNotice(null)}
        />
      )}

      {/* No search box: the server ignores the `search` query parameter (it is documented as
          reserved in api.json), and filtering the fetched page here would silently miss members on
          later pages -- the listing is oldest-membership-first and read one page at a time. Restore
          this control together with server-side search. */}
      <div className="flex items-center justify-end gap-4">
        <div className="flex items-center gap-2">
          <Input
            placeholder="Add existing user by id"
            value={addUserId}
            onChange={(e) => setAddUserId(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') void addMember(); }}
            className="max-w-xs"
          />
          <Button variant="outline" onClick={() => void addMember()} disabled={adding || !addUserId.trim()}>
            Add member
          </Button>
          <InviteMemberDialog
            tenantId={tenantId}
            onInvited={(response) => {
              setRightsNotice(response.invitation.role === 'admin' ? 'invited' : null);
              setInviteLink(response);
            }}
            canInviteAdmin={canGrantAdmin}
          />
        </div>
      </div>

      {/* Members and, beside them on large screens, the details of the picked
          member (#2665): a box below a long list is out of reach without scrolling. */}
      <div className="flex flex-col lg:flex-row gap-6">
        <div className="flex-1 min-w-0 overflow-x-auto">
          <table className="w-full">
            <thead style={{ backgroundColor: 'var(--sg-bg-0)', borderBottom: '1px solid var(--sg-border)' }}>
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Member</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Email</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Role</th>
                <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Joined</th>
                <th className="px-4 py-3 text-right text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(members ?? []).map((member) => (
                <tr
                  key={member.user_id}
                  onClick={() => toggleUser(member.user_id)}
                  onKeyDown={(e) => onRowKeyDown(e, member.user_id)}
                  tabIndex={0}
                  role="button"
                  aria-pressed={selectedUserId === member.user_id}
                  className={`cursor-pointer transition-colors ${
                    selectedUserId === member.user_id
                      ? 'bg-[var(--sg-accent-bg)]'
                      : 'hover:bg-[var(--sg-bg-2)]'
                  }`}
                  style={{ borderBottom: '1px solid var(--sg-border)' }}
                >
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      {/* tenant-member keys the account as `user_id`; the avatar seeds its
                          identicon from `id`, so map it across. */}
                      <Avatar
                        user={{
                          id: member.user_id,
                          name: member.name,
                          email: member.email,
                          avatar_url: member.avatar_url,
                        }}
                        size={32}
                      />
                      <span className="font-medium">{member.name}</span>
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                    {member.email ?? '—'}
                  </td>
                  <td className="px-4 py-3">{renderRole(member)}</td>
                  <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                    <Timestamp date={member.joined_at} relative />
                  </td>
                  <td className="px-4 py-3 text-right" onClick={(e) => e.stopPropagation()}>
                    {renderMemberActions(member)}
                  </td>
                </tr>
              ))}
              {(members ?? []).length === 0 && (
                <tr>
                  <td colSpan={5} className="px-4 py-6 text-center text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                    No members match.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
        {selectedUserId && (
          <UserDetailCard userId={selectedUserId} onClose={() => setSelectedUserId(null)} />
        )}
      </div>

      {(invitations ?? []).length > 0 && (
        <div>
          <h3 className="text-sm font-medium mb-2" style={{ color: 'var(--sg-text-muted)' }}>
            Invitations
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead style={{ backgroundColor: 'var(--sg-bg-0)', borderBottom: '1px solid var(--sg-border)' }}>
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Email</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Role</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Status</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Invited by</th>
                  <th className="px-4 py-3 text-left text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Expires</th>
                  <th className="px-4 py-3 text-right text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {(invitations ?? []).map((invitation) => (
                  <tr key={invitation.id} style={{ borderBottom: '1px solid var(--sg-border)' }}>
                    <td className="px-4 py-3 text-sm">{invitation.email}</td>
                    <td className="px-4 py-3">
                      <Badge variant={invitation.role === 'admin' ? 'default' : 'outline'}>
                        {invitation.role === 'admin' ? 'Admin' : 'Member'}
                      </Badge>
                    </td>
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2">
                        {invitationStatusBadge(invitation)}
                        {invitation.status === 'pending' && invitation.delivered === false && (
                          <span className="text-xs" style={{ color: 'var(--sg-text-muted)' }}>
                            email not delivered
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                      {invitation.invited_by_name}
                    </td>
                    <td className="px-4 py-3 text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                      <Timestamp date={invitation.expires_at} relative />
                    </td>
                    <td className="px-4 py-3 text-right">
                      {(invitation.status === 'pending' || invitation.status === 'expired') && (
                        <div className="flex justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="sm"
                            title="Generate a fresh link (and re-send the email when delivery is configured)"
                            onClick={() =>
                              runAction(
                                invitation.id,
                                async () =>
                                  setInviteLink(await reissueTenantInvitation(tenantId, invitation.id)),
                                'invitation_reissued'
                              )
                            }
                          >
                            <RefreshCw className="h-4 w-4" />
                          </Button>
                          {invitation.status === 'pending' && (
                            <Button
                              variant="ghost"
                              size="sm"
                              title="Revoke this invitation"
                              onClick={() =>
                                runAction(
                                  invitation.id,
                                  () => revokeTenantInvitation(tenantId, invitation.id),
                                  'invitation_revoked'
                                )
                              }
                            >
                              <XCircle className="h-4 w-4" />
                            </Button>
                          )}
                        </div>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Remove-member confirmation */}
      <Dialog open={removing !== null} onOpenChange={(open) => !open && setRemoving(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Remove member</DialogTitle>
            <DialogDescription>
              Remove {removing?.name ?? 'this member'} from the tenant. They keep their account but
              lose access to this tenant&apos;s states and settings.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRemoving(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={removing !== null && busyUserId === removing.user_id}
              onClick={() => {
                if (!removing) return;
                const target = removing;
                setRemoving(null);
                runAction(
                  target.user_id,
                  () => removeTenantMember(tenantId, target.user_id),
                  'member_removed',
                  undefined,
                  () => setRightsNotice('removed')
                );
              }}
            >
              Remove
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* One-time accept link, from an invite or a reissue */}
      <Dialog open={inviteLink !== null} onOpenChange={(open) => !open && setInviteLink(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Invitation link ready</DialogTitle>
            <DialogDescription>
              {inviteLink && invitationLinkMessage(inviteLink.delivery)}
            </DialogDescription>
          </DialogHeader>
          <div className="flex items-center gap-2 py-2">
            <Input readOnly value={inviteLink?.invite_url ?? ''} className="font-mono text-xs" />
            <Button
              variant="outline"
              size="sm"
              onClick={() => inviteLink && copyLink(inviteLink.invite_url)}
            >
              {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
            </Button>
          </div>
          <DialogFooter>
            <Button onClick={() => setInviteLink(null)}>Done</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
