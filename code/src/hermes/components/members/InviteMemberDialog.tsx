'use client';

import { useState } from 'react';
import { createTenantInvitation, InvitationCreateResponse } from '@/lib/api/client';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { UserPlus } from 'lucide-react';
import { track } from '@/lib/analytics';

/**
 * Invite one address to the tenant. On success the parent receives the create
 * response and shows the copyable accept link — the link is returned only once
 * (the server stores the token's hash), so surfacing it is the parent's job and
 * survives this dialog closing.
 */
export function InviteMemberDialog({
  tenantId,
  onInvited,
  canInviteAdmin,
}: {
  tenantId: string;
  onInvited: (response: InvitationCreateResponse) => void;
  /**
   * Whether the viewer administers this tenant. An invitation confers the role it names, and the
   * server requires the sender to hold what they hand out, so a member-manager asking for
   * `tenant_admin` is refused with 403. Hide the option rather than offer a button that cannot work.
   */
  canInviteAdmin: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [email, setEmail] = useState('');
  const [asAdmin, setAsAdmin] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const response = await createTenantInvitation(tenantId, {
        email,
        tenant_admin: asAdmin || undefined,
      });
      track('member_invited', { tenant_admin: asAdmin, delivery: response.delivery });
      setEmail('');
      setAsAdmin(false);
      setOpen(false);
      onInvited(response);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create invitation');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button size="sm">
          <UserPlus className="mr-2 h-4 w-4" />
          Invite Member
        </Button>
      </DialogTrigger>
      <DialogContent>
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Invite a member</DialogTitle>
            <DialogDescription>
              Sends an invitation email when delivery is configured; either way you get a link you
              can pass on yourself.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="invite-email">Email</Label>
              <Input
                id="invite-email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="teammate@example.com"
                required
              />
            </div>
            {canInviteAdmin && (
              <div className="flex items-center gap-2">
                <Checkbox
                  id="invite-admin"
                  checked={asAdmin}
                  onCheckedChange={(v) => setAsAdmin(v === true)}
                />
                <Label htmlFor="invite-admin" className="font-normal">
                  Invite as tenant administrator
                </Label>
              </div>
            )}
            {error && <p className="text-sm text-red-500">{error}</p>}
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={loading}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={loading || !email.trim()}>
              {loading ? 'Inviting…' : 'Send Invitation'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  );
}
