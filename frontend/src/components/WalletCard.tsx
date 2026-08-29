"use client";

import { useEffect, useRef, useState } from "react";
import type { Cat } from "@/lib/api";
import { formatAccountNumber, formatTreats } from "@/lib/format";
import { Avatar } from "./Avatar";

/**
 * Shows the balance, the account number others send to, and briefly the delta when
 * the balance changes.
 *
 * On a polling dashboard a number can change without the reader noticing it did.
 * Surfacing the movement for a moment turns "the balance is 942" into "Whiskers
 * just sent 25" without having to read the ledger.
 */
export function WalletCard({ cat }: { cat: Cat }) {
  const [delta, setDelta] = useState<number | null>(null);
  const previous = useRef(cat.balance);

  useEffect(() => {
    const change = cat.balance - previous.current;
    previous.current = cat.balance;
    if (change === 0) return;

    setDelta(change);
    const timer = setTimeout(() => setDelta(null), 2400);
    return () => clearTimeout(timer);
  }, [cat.balance]);

  return (
    <div className="rounded-2xl border border-[var(--color-line)] bg-[var(--color-surface)] p-5">
      <div className="flex items-center gap-2.5">
        <Avatar name={cat.name} size={28} />
        <div className="min-w-0">
          <div className="truncate text-sm font-bold">{cat.name}</div>
          <div className="tabular text-[11.5px] text-[var(--color-slate)]">
            {formatAccountNumber(cat.accountNumber)}
          </div>
        </div>
      </div>

      <div className="mt-4 flex items-baseline gap-1.5">
        <span className="headline tabular text-[30px] leading-none">
          {formatTreats(cat.balance)}
        </span>
        <span className="text-xs text-[var(--color-slate)]">treats</span>

        {/* Reserved space, so the row does not jump when a delta appears. */}
        <span className="ml-auto h-4 text-xs font-bold">
          {delta !== null && (
            <span
              className="tabular"
              style={{
                color:
                  delta > 0
                    ? "var(--color-positive)"
                    : "var(--color-coral-ink)",
              }}
            >
              {delta > 0 ? "+" : "−"}
              {formatTreats(Math.abs(delta))}
            </span>
          )}
        </span>
      </div>
    </div>
  );
}

export function WalletCardSkeleton() {
  return (
    <div className="h-[132px] animate-pulse rounded-2xl border border-[var(--color-line)] bg-[var(--color-surface)]" />
  );
}
