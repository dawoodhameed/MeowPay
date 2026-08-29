"use client";

import type { LedgerEntry } from "@/lib/api";
import { formatAbsolute, formatRelative, formatTreats } from "@/lib/format";
import { Avatar } from "./Avatar";

export function LedgerTable({
  entries,
  newIds,
  now,
}: {
  entries: LedgerEntry[];
  newIds: Set<string>;
  now: number;
}) {
  if (entries.length === 0) {
    return (
      <div className="px-5 py-16 text-center">
        <p className="text-sm font-medium">No transfers yet</p>
        <p className="mx-auto mt-1.5 max-w-xs text-xs leading-relaxed text-[var(--color-muted)]">
          Send treats from the mobile app and they will appear here within a
          second.
        </p>
      </div>
    );
  }

  return (
    // Scrolls inside its own container, so a narrow viewport never makes the whole
    // page scroll sideways.
    <div className="overflow-x-auto">
      <table className="w-full min-w-[520px] border-collapse">
        <thead>
          <tr className="border-b border-[var(--color-line)]">
            <th className="px-5 py-2.5 text-left text-[10px] font-medium tracking-[0.08em] text-[var(--color-muted)] uppercase">
              Transfer
            </th>
            <th className="px-5 py-2.5 text-right text-[10px] font-medium tracking-[0.08em] text-[var(--color-muted)] uppercase">
              Amount
            </th>
            <th className="px-5 py-2.5 text-right text-[10px] font-medium tracking-[0.08em] text-[var(--color-muted)] uppercase">
              When
            </th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry) => (
            <tr
              key={entry.id}
              title={formatAbsolute(entry.createdAt)}
              className={`border-b border-[var(--color-line-soft)] last:border-0 ${
                newIds.has(entry.id) ? "row-new" : ""
              }`}
            >
              {/* Sender and recipient sit in one cell joined by an arrow: direction is
                  the point of a ledger line, and splitting them across columns makes
                  the reader reconstruct it. */}
              <td className="px-5 py-3">
                <div className="flex items-center gap-2 text-sm whitespace-nowrap">
                  <Avatar name={entry.sender.catName} size={22} />
                  <span>{entry.sender.catName}</span>
                  <svg
                    aria-label="sent to"
                    role="img"
                    width="14"
                    height="14"
                    viewBox="0 0 24 24"
                    fill="none"
                    className="shrink-0 text-[var(--color-muted)]"
                  >
                    <path
                      d="M5 12h13m0 0-4.5-4.5M18 12l-4.5 4.5"
                      stroke="currentColor"
                      strokeWidth="1.7"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                  <Avatar name={entry.recipient.catName} size={22} />
                  <span>{entry.recipient.catName}</span>
                </div>
              </td>

              {/* Neutral, not green. In a system-wide ledger a transfer is a movement,
                  not a credit -- colouring every amount as a gain misreads it. */}
              <td className="tabular px-5 py-3 text-right text-sm font-medium whitespace-nowrap">
                {formatTreats(entry.amount)}
              </td>

              <td className="px-5 py-3 text-right text-xs whitespace-nowrap text-[var(--color-muted)]">
                {formatRelative(entry.createdAt, now)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
