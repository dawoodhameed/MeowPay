/** Grouped digits so a four-figure balance is readable at a glance. */
export function formatTreats(amount: number): string {
  return new Intl.NumberFormat('en-US').format(amount);
}

/**
 * Ledger timestamps are rendered in the reader's own timezone. The API returns UTC
 * instants; showing them raw would misreport when a transfer happened for anyone
 * outside UTC.
 */
export function formatTimestamp(iso: string): string {
  return new Date(iso).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString([], { month: 'short', day: 'numeric' });
}
