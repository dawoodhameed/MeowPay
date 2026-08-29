import type { LedgerEntry } from '@/lib/api';
import { formatDate, formatTimestamp, formatTreats } from '@/lib/format';

export function LedgerTable({ entries }: { entries: LedgerEntry[] }) {
  if (entries.length === 0) {
    return (
      <div className="px-5 py-14 text-center">
        <p className="text-sm text-[var(--color-text)]">No transfers yet</p>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Send treats from the mobile app and they will appear here.
        </p>
      </div>
    );
  }

  return (
    // The table scrolls inside its own container so a narrow viewport never makes the
    // whole page scroll sideways.
    <div className="overflow-x-auto">
      <table className="w-full min-w-[560px] border-collapse">
        <thead>
          <tr className="border-b border-[var(--color-line)]">
            {['Time', 'From', 'To', 'Amount', 'Status'].map((heading, i) => (
              <th
                key={heading}
                className={`px-5 py-2.5 text-[11px] font-medium tracking-wider text-[var(--color-muted)] uppercase ${
                  i >= 3 ? 'text-right' : 'text-left'
                }`}
              >
                {heading}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr
              key={entry.id}
              className="border-b border-[var(--color-line)]/60 last:border-0 hover:bg-white/[0.02]"
            >
              <td className="px-5 py-3 whitespace-nowrap">
                <span className="tabular text-sm text-[var(--color-text)]">
                  {formatTimestamp(entry.createdAt)}
                </span>
                <span className="ml-2 text-xs text-[var(--color-muted)]">
                  {formatDate(entry.createdAt)}
                </span>
              </td>
              <td className="px-5 py-3 text-sm whitespace-nowrap text-[var(--color-text)]">
                {entry.sender.catName}
              </td>
              <td className="px-5 py-3 text-sm whitespace-nowrap text-[var(--color-text)]">
                {entry.recipient.catName}
              </td>
              <td className="tabular px-5 py-3 text-right text-sm font-medium whitespace-nowrap text-[var(--color-credit)]">
                {formatTreats(entry.amount)}
              </td>
              <td className="px-5 py-3 text-right whitespace-nowrap">
                <span className="rounded-full border border-[var(--color-credit)]/25 bg-[var(--color-credit)]/10 px-2 py-0.5 text-[10px] font-medium tracking-wide text-[var(--color-credit)]">
                  {entry.status}
                </span>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
