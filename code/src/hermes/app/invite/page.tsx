'use client';

import { Suspense, useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  InvitationAcceptResponse,
  InvitationPreviewResponse,
  User,
  acceptInvitation,
  checkAuth,
  previewInvitation,
} from '@/lib/api/client';
import { Button } from '@/components/ui/button';
import { track } from '@/lib/analytics';

function LoadingState({ message }: { message: string }) {
  return (
    <div className="flex items-center justify-center min-h-screen bg-[var(--sg-bg-0)]">
      <p className="text-[var(--sg-text-muted)]">{message}</p>
    </div>
  );
}

/**
 * The invitation accept page. The backend mints links of the form
 * `/invite/?token=…` (sgs_service_tenants_invitation_common.ml — trailing slash required by the
 * static export), and the token is the credential: the preview needs no
 * session, acceptance does. An unauthenticated visitor bounces through
 * `/login?next=` and lands back here signed in.
 */
function InviteContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const token = searchParams.get('token');

  const [preview, setPreview] = useState<InvitationPreviewResponse | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [checking, setChecking] = useState(true);
  const [accepting, setAccepting] = useState(false);
  const [acceptError, setAcceptError] = useState<string | null>(null);
  const [accepted, setAccepted] = useState<InvitationAcceptResponse | null>(null);

  useEffect(() => {
    if (!token) {
      setPreviewError('This link is missing its invitation token.');
      setChecking(false);
      return;
    }
    (async () => {
      try {
        const [p, u] = await Promise.all([previewInvitation(token), checkAuth()]);
        setPreview(p);
        setUser(u);
      } catch (err) {
        setPreviewError(
          err instanceof Error ? err.message : 'This invitation could not be loaded.'
        );
      } finally {
        setChecking(false);
      }
    })();
  }, [token]);

  const handleAccept = async () => {
    if (!token) return;
    setAcceptError(null);
    setAccepting(true);
    try {
      const result = await acceptInvitation(token);
      track('invitation_accepted', {
        already_member: result.already_member,
        email_mismatch: result.email_mismatch,
      });
      setAccepted(result);
    } catch (err) {
      setAcceptError(err instanceof Error ? err.message : 'Failed to accept the invitation.');
    } finally {
      setAccepting(false);
    }
  };

  const handleSignIn = () => {
    if (!token) return;
    const next = `/invite/?token=${encodeURIComponent(token)}`;
    router.push(`/login/?next=${encodeURIComponent(next)}`);
  };

  if (checking) {
    return <LoadingState message="Loading invitation..." />;
  }

  const unavailable: Record<string, string> = {
    accepted: 'This invitation has already been used. If that was you, just sign in.',
    revoked: 'This invitation was revoked. Ask the person who invited you for a new one.',
    expired: 'This invitation has expired. Ask the person who invited you to reissue it.',
  };

  return (
    <div className="flex flex-col items-center justify-center min-h-screen bg-[var(--sg-bg-0)]">
      <div className="max-w-md w-full px-8">
        <div className="text-center mb-8">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_white.svg"
            alt="Stategraph"
            className="h-10 mx-auto mb-6 hidden dark:block"
          />
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src="/logos/stategraph_logo_wordmark_blue.svg"
            alt="Stategraph"
            className="h-10 mx-auto mb-6 dark:hidden"
          />

          {previewError ? (
            <>
              <h1 className="text-2xl font-bold text-[var(--sg-text)]">Invitation unavailable</h1>
              <p className="text-[var(--sg-text-muted)] mt-2">{previewError}</p>
            </>
          ) : accepted ? (
            <>
              <h1 className="text-2xl font-bold text-[var(--sg-text)]">
                {accepted.already_member ? 'You already had access' : `Welcome to ${accepted.tenant_name}`}
              </h1>
              <p className="text-[var(--sg-text-muted)] mt-2">
                {accepted.already_member
                  ? `You were already a member of ${accepted.tenant_name}.`
                  : `You are now a member of ${accepted.tenant_name}.`}
              </p>
              {accepted.email_mismatch && (
                <p className="text-[var(--sg-text-muted)] mt-2 text-sm">
                  Note: you signed in with a different address than the invitation was sent to. The
                  join succeeded; the mismatch was recorded.
                </p>
              )}
              <Button className="mt-6" onClick={() => router.push('/')}>
                Open the console
              </Button>
            </>
          ) : preview && preview.status !== 'pending' ? (
            <>
              <h1 className="text-2xl font-bold text-[var(--sg-text)]">Invitation unavailable</h1>
              <p className="text-[var(--sg-text-muted)] mt-2">{unavailable[preview.status]}</p>
              {preview.status === 'accepted' && (
                <Button className="mt-6" onClick={() => router.push('/login/')}>
                  Sign in
                </Button>
              )}
            </>
          ) : preview ? (
            <>
              <h1 className="text-2xl font-bold text-[var(--sg-text)]">
                Join {preview.tenant_name}
              </h1>
              <p className="text-[var(--sg-text-muted)] mt-2">
                {preview.inviter_name} invited {preview.invited_email_masked} to join{' '}
                {preview.tenant_name}
                {preview.role === 'admin' ? ' as a tenant administrator' : ''}.
              </p>
              {acceptError && <p className="text-sm text-red-500 mt-4">{acceptError}</p>}
              {user ? (
                <>
                  <Button className="mt-6" onClick={handleAccept} disabled={accepting}>
                    {accepting ? 'Joining…' : 'Accept invitation'}
                  </Button>
                  <p className="text-[var(--sg-text-muted)] mt-3 text-xs">
                    Signed in as {user.name}
                  </p>
                </>
              ) : (
                <>
                  <Button className="mt-6" onClick={handleSignIn}>
                    Sign in to accept
                  </Button>
                  <p className="text-[var(--sg-text-muted)] mt-3 text-xs">
                    You&apos;ll come straight back here after signing in.
                  </p>
                </>
              )}
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export default function InvitePage() {
  return (
    <Suspense fallback={<LoadingState message="Loading..." />}>
      <InviteContent />
    </Suspense>
  );
}
