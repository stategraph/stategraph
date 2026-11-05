'use client';

import { useState, useEffect } from 'react';
import { getUserDetail, updateUser } from '@/lib/api/client';
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useAuth } from '@/components/auth/AuthProvider';
import { isInstanceAdmin } from '@/lib/api/capabilities';

interface EditUserDialogProps {
  userId: string;
  onClose: () => void;
  onSuccess: () => void;
}

export function EditUserDialog({ userId, onClose, onSuccess }: EditUserDialogProps) {
  const { user: currentUser } = useAuth();
  const [loading, setLoading] = useState(false);
  const [fetchLoading, setFetchLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Form state
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [avatarUrl, setAvatarUrl] = useState('');
  const [userType, setUserType] = useState('');
  const [authOrigin, setAuthOrigin] = useState<string | null>(null);

  // /api/v1/users/update requires an unscoped grant to change another user's email, so this
  // gate must be installation-wide -- a tenant-scoped admin is not an installation admin.
  const isAdmin = isInstanceAdmin(currentUser?.capabilities);
  const canEditEmail = isAdmin && !authOrigin; // Can't change OAuth user email

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const user = await getUserDetail(userId);
        setName(user.name);
        setEmail(user.email || '');
        setAvatarUrl(user.avatar_url || '');
        setUserType(user.type);
        setAuthOrigin(user.auth_origin || null);
      } catch (_err) {
        setError('Failed to load user details');
      } finally {
        setFetchLoading(false);
      }
    };
    fetchUser();
  }, [userId]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      await updateUser(userId, {
        name: name !== '' ? name : undefined,
        email: canEditEmail && email !== '' ? email : undefined,
        avatar_url: avatarUrl !== '' ? avatarUrl : undefined,
      });

      onSuccess();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to update user');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Dialog open onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>Edit User</DialogTitle>
          <DialogDescription>
            Update user information. {!isAdmin && 'You can only edit your own name and avatar.'}
          </DialogDescription>
        </DialogHeader>
        {fetchLoading ? (
          <div className="p-6 text-center">Loading...</div>
        ) : (
          <form onSubmit={handleSubmit}>

            <div className="grid gap-4 py-4">
              {error && (
                <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-2 rounded-md text-sm">
                  {error}
                </div>
              )}

              <div className="grid gap-2">
                <Label htmlFor="edit-name">Name</Label>
                <Input
                  id="edit-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>

              <div className="grid gap-2">
                <Label htmlFor="edit-email">Email</Label>
                <Input
                  id="edit-email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={!canEditEmail}
                />
                {authOrigin && (
                  <p className="text-xs text-gray-500">
                    Email cannot be changed for OAuth users (authenticated via {authOrigin})
                  </p>
                )}
                {!isAdmin && (
                  <p className="text-xs text-gray-500">
                    Only admins can change email addresses
                  </p>
                )}
              </div>

              <div className="grid gap-2">
                <Label htmlFor="edit-avatar">Avatar URL</Label>
                <Input
                  id="edit-avatar"
                  value={avatarUrl}
                  onChange={(e) => setAvatarUrl(e.target.value)}
                  placeholder="https://example.com/avatar.jpg"
                />
              </div>

              <div className="grid gap-2">
                <Label>Type</Label>
                <div className="px-3 py-2 bg-gray-50 rounded-md text-sm text-gray-600">
                  {userType}
                </div>
              </div>
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={onClose} disabled={loading}>
                Cancel
              </Button>
              <Button type="submit" disabled={loading || !name.trim()}>
                {loading ? 'Saving...' : 'Save Changes'}
              </Button>
            </DialogFooter>
          </form>
        )}
      </DialogContent>
    </Dialog>
  );
}
