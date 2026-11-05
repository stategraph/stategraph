'use client';

import { useState, useEffect } from 'react';
import { getUserDetail, deleteUser } from '@/lib/api/client';
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
import { AlertTriangle } from 'lucide-react';

interface DeleteUserDialogProps {
  userId: string;
  onClose: () => void;
  onSuccess: () => void;
}

export function DeleteUserDialog({ userId, onClose, onSuccess }: DeleteUserDialogProps) {
  const [loading, setLoading] = useState(false);
  const [fetchLoading, setFetchLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [userName, setUserName] = useState('');
  const [userEmail, setUserEmail] = useState('');
  const [confirmText, setConfirmText] = useState('');

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const user = await getUserDetail(userId);
        setUserName(user.name);
        setUserEmail(user.email || '');
      } catch (_err) {
        setError('Failed to load user details');
      } finally {
        setFetchLoading(false);
      }
    };
    fetchUser();
  }, [userId]);

  const handleDelete = async () => {
    setError(null);
    setLoading(true);

    try {
      await deleteUser(userId);
      onSuccess();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to delete user');
    } finally {
      setLoading(false);
    }
  };

  const confirmEmail = userEmail || userName;
  const isConfirmed = confirmText === confirmEmail;

  return (
    <Dialog open onOpenChange={onClose}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2 text-red-600">
            <AlertTriangle className="h-5 w-5" />
            Delete User
          </DialogTitle>
          <DialogDescription>
            This action cannot be undone. The user will be permanently deleted from the system.
          </DialogDescription>
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

              <div className="bg-gray-50 border border-gray-200 rounded-md p-4">
                <div className="font-medium">{userName}</div>
                {userEmail && <div className="text-sm text-gray-600">{userEmail}</div>}
              </div>

              <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-md text-sm">
                <strong>Warning:</strong> This will delete the user account and they will no longer be able to access
                the system.
              </div>

              <div className="grid gap-2">
                <Label htmlFor="confirm-delete">
                  Type <strong>{confirmEmail}</strong> to confirm deletion
                </Label>
                <Input
                  id="confirm-delete"
                  value={confirmText}
                  onChange={(e) => setConfirmText(e.target.value)}
                  placeholder={confirmEmail}
                />
              </div>
            </div>

            <DialogFooter>
              <Button type="button" variant="outline" onClick={onClose} disabled={loading}>
                Cancel
              </Button>
              <Button
                type="button"
                variant="destructive"
                onClick={handleDelete}
                disabled={!isConfirmed || loading}
              >
                {loading ? 'Deleting...' : 'Delete User'}
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
