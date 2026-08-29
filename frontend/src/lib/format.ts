export function formatTreats(amount: number): string {
  return new Intl.NumberFormat("en-US").format(amount);
}

/**
 * Recency is what matters on a live feed -- "12s ago" answers "is this still
 * moving?" at a glance, where a wall-clock time makes the reader do arithmetic.
 * The absolute time stays available in the row's title attribute.
 */
export function formatRelative(iso: string, now: number = Date.now()): string {
  const seconds = Math.max(
    0,
    Math.round((now - new Date(iso).getTime()) / 1000),
  );
  if (seconds < 5) return "just now";
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export function formatAbsolute(iso: string): string {
  return new Date(iso).toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

export const AVATAR_COLORS = [
  { bg: "rgba(61,220,151,0.13)", fg: "#3ddc97" },
  { bg: "rgba(122,162,255,0.13)", fg: "#7aa2ff" },
  { bg: "rgba(255,181,107,0.13)", fg: "#ffb56b" },
  { bg: "rgba(214,140,255,0.13)", fg: "#d68cff" },
  { bg: "rgba(255,139,107,0.13)", fg: "#ff8b6b" },
];

/**
 * Fallback for a name that is not in the current cat list -- a ledger row whose cat
 * has since been removed, say. Hashing alone is not good enough for the main case:
 * over a handful of names collisions are likely rather than rare, and "Whiskers" and
 * "Mittens" did in fact land on the same colour, which defeats the point of colouring
 * them at all. Assignment by position is what guarantees the visible set is distinct.
 */
export function fallbackAvatarColor(name: string) {
  let hash = 0;
  for (let i = 0; i < name.length; i += 1) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  return AVATAR_COLORS[hash % AVATAR_COLORS.length];
}

export function initialOf(name: string): string {
  return name.charAt(0).toUpperCase();
}
