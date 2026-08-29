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

/**
 * The same five colours, in the same order, as the Flutter app's palette. A cat
 * that is coral on the phone must be coral here; the two clients read as one
 * product only if identity survives the platform boundary.
 */
export const AVATAR_COLORS = [
  { bg: "rgba(255,123,102,0.14)", fg: "#C4462F" },
  { bg: "rgba(22,74,100,0.12)", fg: "#164A64" },
  { bg: "rgba(14,159,110,0.13)", fg: "#0B7D57" },
  { bg: "rgba(140,91,216,0.13)", fg: "#6D3FB0" },
  { bg: "rgba(224,138,46,0.14)", fg: "#A96114" },
];

/**
 * Fallback for a name not in the current cat list. Hashing alone is not good
 * enough for the main case: over a handful of names collisions are likely rather
 * than rare, which is why the visible set is assigned by position instead.
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

/** Grouped for reading, matching how the mobile app prints them: `1000 0001`. */
export function formatAccountNumber(raw: string): string {
  return raw.length === 8 ? `${raw.slice(0, 4)} ${raw.slice(4)}` : raw;
}
