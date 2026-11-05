'use client';

import { useEffect, useState } from 'react';
import { getUserDetail, type UserDetailResponse } from '@/lib/api/client';
import { Avatar } from '@/components/ui/avatar';
import { Button } from '@/components/ui/button';
import { CopyButton } from '@/components/ui/copy-button';
import { Timestamp } from '@/components/ui/timestamp';
import { X } from 'lucide-react';
import { capabilitiesNote, membershipsScopeNote, userDetailFacts } from './userDetailFacts';

interface UserDetailCardProps {
  userId: string;
  onClose: () => void;
}

type FetchState =
  | { status: 'loading' }
  | { status: 'error'; message: string }
  | { status: 'done'; detail: UserDetailResponse };

/**
 * The details box that opens beside a user list when an entry is picked
 * (#2665). On large screens it is a sticky column to the right of the list, so
 * a long list cannot put the box out of reach; below `lg` it stacks after the
 * list. Fetches `/api/v1/users/detail` for the picked user: that endpoint
 * answers an installation admin in full, and a tenant admin or users-manage
 * holder with the memberships its grant reaches (see {@link membershipsScopeNote}).
 * The callers here -- the Members and Admin tabs -- gate on those same grants,
 * so every row the lists show is readable by the viewers who see them.
 * The capabilities come only to a viewer that can edit the user (see
 * {@link capabilitiesNote}), and are shown verbatim, as `PermissionInfo`
 * shows the session's own: what explains a refusal is the exact grant, not an
 * interpretation of it.
 */
export function UserDetailCard({ userId, onClose }: UserDetailCardProps) {
  // Retry bumps `attempt` to run the fetch again. The answer is stored against
  // the selection it answers, and what is on screen is derived from the current
  // key: an answer from a previous selection (or an earlier retry) that comes
  // back late shows up against a stale key and is ignored.
  const [attempt, setAttempt] = useState(0);
  const key = `${userId}#${attempt}`;
  const [fetched, setFetched] = useState<{ key: string; state: FetchState } | null>(null);
  const state: FetchState = fetched?.key === key ? fetched.state : { status: 'loading' };

  useEffect(() => {
    let stale = false;
    getUserDetail(userId).then(
      (detail) => {
        if (!stale) setFetched({ key, state: { status: 'done', detail } });
      },
      (err: unknown) => {
        if (!stale) {
          setFetched({
            key,
            state: {
              status: 'error',
              message: err instanceof Error ? err.message : 'Failed to load user details',
            },
          });
        }
      }
    );
    return () => {
      stale = true;
    };
  }, [userId, key]);

  const scopeNote = state.status === 'done' ? membershipsScopeNote(state.detail) : null;
  const capsNote = state.status === 'done' ? capabilitiesNote(state.detail) : null;
  const capsJson =
    state.status === 'done' && state.detail.capabilities
      ? JSON.stringify(state.detail.capabilities, null, 2)
      : null;

  return (
    // The bounded height keeps a many-tenant box scrollable while it is pinned. The width follows the
    // widest line, the capabilities' usually, from 300 up to 480px; past that the capabilities scroll,
    // with a visible scrollbar (`scrollable`): globals.css hides them, which made a wide grant look clipped.
    <aside
      aria-label="User details"
      className="w-full lg:w-fit lg:min-w-[300px] lg:max-w-[480px] shrink-0 lg:sticky lg:top-6 lg:self-start lg:max-h-[calc(100vh-var(--sg-nav-height)-2.5rem)] lg:overflow-y-auto rounded-lg border border-[var(--sg-border)] bg-[var(--sg-bg-1)] p-4 space-y-4"
    >
      <div className="flex items-start justify-between gap-3">
        <h3 className="text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>
          User details
        </h3>
        <Button variant="ghost" size="sm" aria-label="Close user details" title="Close" onClick={onClose}>
          <X className="h-4 w-4" />
        </Button>
      </div>

      {state.status === 'loading' && (
        <div className="text-sm" style={{ color: 'var(--sg-text-muted)' }}>
          Loading user details...
        </div>
      )}

      {state.status === 'error' && (
        <div className="flex items-center gap-3 text-sm text-red-500">
          <span>{state.message}</span>
          <Button variant="outline" size="sm" onClick={() => setAttempt((a) => a + 1)}>
            Retry
          </Button>
        </div>
      )}

      {state.status === 'done' && (
        <>
          <div className="flex items-center gap-3 min-w-0">
            <Avatar user={state.detail} size={36} />
            <div className="min-w-0">
              <div className="font-medium truncate">{state.detail.name}</div>
              <div className="text-xs" style={{ color: 'var(--sg-text-muted)' }}>
                Created <Timestamp date={state.detail.created_at} relative />
              </div>
            </div>
          </div>

          <dl className="space-y-2">
            {userDetailFacts(state.detail).map((fact) => (
              <div key={fact.label} className="flex items-baseline gap-2 text-sm">
                <dt className="w-20 shrink-0" style={{ color: 'var(--sg-text-muted)' }}>
                  {fact.label}
                </dt>
                <dd
                  className={`break-all ${fact.mono ? 'text-xs font-mono' : ''}`}
                  style={{ color: 'var(--sg-text)' }}
                >
                  {fact.value}
                </dd>
              </div>
            ))}
          </dl>

          <div>
            <h4 className="text-xs font-medium uppercase mb-2" style={{ color: 'var(--sg-text-muted)' }}>
              Tenant memberships
            </h4>
            {state.detail.tenants.length === 0 ? (
              <p className="text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                This user belongs to no tenant.
              </p>
            ) : (
              <ul className="space-y-1">
                {state.detail.tenants.map((tenant) => (
                  <li key={tenant.id} className="flex items-baseline gap-2 text-sm">
                    <span style={{ color: 'var(--sg-text)' }}>{tenant.name}</span>
                    <span className="text-xs font-mono break-all" style={{ color: 'var(--sg-text-dim)' }}>
                      {tenant.id}
                    </span>
                  </li>
                ))}
              </ul>
            )}
            {scopeNote && (
              <p className="mt-2 text-xs" style={{ color: 'var(--sg-text-muted)' }}>
                {scopeNote}
              </p>
            )}
          </div>

          <div>
            <div className="flex items-center justify-between gap-2 mb-2">
              <h4 className="text-xs font-medium uppercase" style={{ color: 'var(--sg-text-muted)' }}>
                Capabilities
              </h4>
              {capsJson !== null && <CopyButton text={capsJson} />}
            </div>
            {capsJson === null ? (
              <p className="text-sm" style={{ color: 'var(--sg-text-muted)' }}>
                {capsNote}
              </p>
            ) : (
              <pre className="text-xs font-mono bg-[var(--sg-bg-0)] border border-[var(--sg-border)] rounded p-2 scrollable text-[var(--sg-text)]">
                {capsJson}
              </pre>
            )}
          </div>
        </>
      )}
    </aside>
  );
}
