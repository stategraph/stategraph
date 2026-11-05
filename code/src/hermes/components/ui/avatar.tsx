"use client";

import { useMemo, useState } from 'react';
import { generateIdenticon, getUserSeed } from '@/lib/utils/identicon';

interface AvatarProps {
  user?: { id?: string; email?: string; name?: string; avatar_url?: string } | null;
  sessionId?: string | null;
  size?: number;
  className?: string;
}

/**
 * Avatar component with deterministic identicon fallback
 * - If user has an avatar_url (from OAuth provider), renders it
 * - Otherwise, renders a deterministic identicon based on user.id, user.email, or sessionId
 */
export function Avatar({ user, sessionId, size = 36, className = '' }: AvatarProps) {
  const [imageError, setImageError] = useState(false);

  // Generate identicon from stable seed (used as fallback)
  const identiconSvg = useMemo(() => {
    const seed = getUserSeed(user, sessionId);
    return generateIdenticon(seed, size);
  }, [user, sessionId, size]);

  // Convert SVG string to data URL for fallback
  const fallbackUrl = `data:image/svg+xml,${encodeURIComponent(identiconSvg)}`;

  // Use avatar_url if available and no error occurred, otherwise use identicon
  const avatarUrl = user?.avatar_url && !imageError ? user.avatar_url : fallbackUrl;

  return (
    <div
      className={`rounded-full overflow-hidden flex-shrink-0 ${className}`}
      style={{ width: size, height: size }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={avatarUrl}
        alt={user?.name || 'User avatar'}
        width={size}
        height={size}
        style={{ display: 'block', objectFit: 'cover' }}
        onError={() => setImageError(true)}
        referrerPolicy="no-referrer"
      />
    </div>
  );
}
