'use client';

import { useState, useEffect } from 'react';
import { getUserDetail, setUserInstanceAdmin } from '@/lib/api/client';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Shield, ShieldOff } from 'lucide-react';
import { roleLabel, setInstanceAdminLabel, type AdminScope } from './adminScope';

function getActionButtonText(loading: boolean, scope: AdminScope): string {
  if (loading) {
    return scope === 'instance' ? 'Removing...' : 'Granting...';
  }
  return setInstanceAdminLabel(scope);
}

function describeAction(scope: AdminScope, name: string): string {
  switch (scope) {
    case 'instance':
      return `Remove ${name}'s installation-wide admin grant. They will become a regular user.`;
    case 'tenants':
      return `Grant ${name} admin over the whole installation, in place of their admin over some tenants. They will have full system access.`;
    case 'none':
      return `Grant ${name} admin over the whole installation. They will have full system access.`;
  }
}

interface SetInstanceAdminDialogProps {
  userId: string;
  scope: AdminScope;
  onClose: () => void;
  onSuccess: () => void;
}

export function SetInstanceAdminDialog({
  userId,
  scope,
  onClose,
  onSuccess,
}: SetInstanceAdminDialogProps) {
  const [loading, setLoading] = useState(false);
  const [fetchLoading, setFetchLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [userName, setUserName] = useState('');

  const isRemoving = scope === 'instance';
  const newValue = !isRemoving;

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const user = await getUserDetail(userId);
        setUserName(user.name);
      } catch (_err) {
        setError('Failed to load user details');
      } finally {
        setFetchLoading(false);
      }
    };
    fetchUser();
  }, [userId]);

  const handleConfirm = async () => {
    setError(null);
    setLoading(true);

    try {
      await setUserInstanceAdmin(userId, newValue);
      onSuccess();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : `Failed to ${isRemoving ? 'remove' : 'grant'} admin privileges`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            {isRemoving ? (
              <ShieldOff className="h-5 w-5 text-orange-600" />
            ) : (
              <Shield className="h-5 w-5 text-purple-600" />
            )}
            {setInstanceAdminLabel(scope)}
          </DialogTitle>
          <DialogDescription>{describeAction(scope, userName || 'this user')}</DialogDescription>
        </DialogHeader>
        {fetchLoading ? (
          <div className="p-6 text-center">Loading...</div>
        ) : (
          <>
            <div className="grid gap-4 py-4">
              {error && (
                <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-2 rounded-md text-sm">
                  {error}
                </div>
              )}

              <div
                className="rounded-md p-4"
                style={{ backgroundColor: 'var(--sg-bg-0)', border: '1px solid var(--sg-border)' }}
              >
                <div className="font-medium">{userName}</div>
                <div className="text-sm mt-1" style={{ color: 'var(--sg-text-muted)' }}>
                  Current role:{' '}
                  {isRemoving ? (
                    <span className="text-purple-600 font-medium">{roleLabel(scope)}</span>
                  ) : (
                    <span>{roleLabel(scope)}</span>
                  )}
                </div>
              </div>

              {scope === 'instance' && (
                <div className="bg-orange-50 border border-orange-200 text-orange-700 px-4 py-3 rounded-md text-sm">
                  After removing installation-wide admin, they will:
                  <ul className="list-disc list-inside mt-2 space-y-1">
                    <li>Lose access to user management</li>
                    <li>Unable to create or modify tenants</li>
                    <li>Only view their own resources</li>
                  </ul>
                </div>
              )}

              {scope !== 'instance' && (
                <div className="bg-purple-50 border border-purple-200 text-purple-700 px-4 py-3 rounded-md text-sm">
                  After granting installation-wide admin, they will have:
                  <ul className="list-disc list-inside mt-2 space-y-1">
                    <li>Full access to user management</li>
                    <li>Ability to create and manage all tenants</li>
                    <li>Access to all system resources</li>
                  </ul>
                </div>
              )}

              {scope === 'tenants' && (
                <div className="bg-orange-50 border border-orange-200 text-orange-700 px-4 py-3 rounded-md text-sm">
                  This replaces their admin grants on individual tenants, and removing
                  installation-wide admin later will not bring them back: each tenant would have to
                  grant the admin role again from its members screen. If they will never need to go
                  back to tenant-scoped admin rights, this is fine.
                </div>
              )}
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={onClose} disabled={loading}>
                Cancel
              </Button>
              <Button
                type="button"
                variant={isRemoving ? 'destructive' : 'default'}
                onClick={handleConfirm}
                disabled={loading}
              >
                {getActionButtonText(loading, scope)}
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
