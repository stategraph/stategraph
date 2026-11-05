/**
 * Deterministic identicon generator for user avatars
 * Creates a 5x5 grid-based pattern from a seed string
 */

/**
 * Simple deterministic hash function
 * Returns a number from a string seed
 */
function simpleHash(str: string): number {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash);
}

/**
 * Generate a deterministic color from seed
 * Uses muted colors suitable for enterprise UI
 */
function generateColor(seed: string): string {
  const hash = simpleHash(seed);

  // Use theme-friendly colors - muted versions of accent colors
  const colors = [
    '#60a5fa', // blue (accent)
    '#34d399', // green
    '#f472b6', // pink
    '#a78bfa', // purple
    '#fb923c', // orange
    '#fbbf24', // yellow
    '#f87171', // red
    '#14b8a6', // teal
  ];

  return colors[hash % colors.length];
}

/**
 * Generate a 5x5 grid pattern from seed
 * Returns an array of 25 booleans (true = filled, false = empty)
 * Uses mirror symmetry for better aesthetics
 */
function generatePattern(seed: string): boolean[] {
  const hash = simpleHash(seed);
  const pattern: boolean[] = [];

  // Generate a 5x5 grid with horizontal symmetry
  // Only need to generate left half (3 columns), mirror for right half
  for (let row = 0; row < 5; row++) {
    for (let col = 0; col < 5; col++) {
      if (col < 2) {
        // Left side - generate based on hash
        const index = row * 3 + col;
        const bit = (hash >> index) & 1;
        pattern.push(bit === 1);
      } else if (col === 2) {
        // Middle column - generate based on hash
        const index = row * 3 + 2;
        const bit = (hash >> index) & 1;
        pattern.push(bit === 1);
      } else {
        // Right side - mirror left side
        const mirrorCol = 4 - col;
        const mirrorIndex = row * 5 + mirrorCol;
        pattern.push(pattern[mirrorIndex]);
      }
    }
  }

  return pattern;
}

/**
 * Generate SVG identicon from seed string
 * @param seed - Stable identifier (user.id, email, etc.)
 * @param size - Size in pixels (default: 40)
 * @returns SVG markup string
 */
export function generateIdenticon(seed: string, size: number = 40): string {
  const color = generateColor(seed);
  const pattern = generatePattern(seed);

  const cellSize = size / 5;
  const cells: string[] = [];

  for (let i = 0; i < 25; i++) {
    if (pattern[i]) {
      const row = Math.floor(i / 5);
      const col = i % 5;
      const x = col * cellSize;
      const y = row * cellSize;

      cells.push(
        `<rect x="${x}" y="${y}" width="${cellSize}" height="${cellSize}" fill="${color}"/>`
      );
    }
  }

  const svg = `
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${size}" height="${size}" fill="var(--sg-bg-2)"/>
      ${cells.join('')}
    </svg>
  `.trim();

  return svg;
}

/**
 * Get stable seed from user data
 * Priority: user.id > user.email > sessionId > "anonymous"
 */
export function getUserSeed(user?: { id?: string; email?: string } | null, sessionId?: string | null): string {
  if (user?.id) return user.id;
  if (user?.email) return user.email;
  if (sessionId) return sessionId;
  return 'anonymous';
}
