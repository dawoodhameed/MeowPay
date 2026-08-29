"use client";

import { useEffect, useRef, useState } from "react";
import type { Cat } from "@/lib/api";
import { formatTreats } from "@/lib/format";
import { Avatar } from "./Avatar";

/**
 * Shows the balance, and briefly shows the delta when it changes.
 *
 * On a polling dashboard a number can change without the reader noticing it did.
 * Surfacing the movement for a moment is what turns "the balance is 942" into
 * "Whiskers just sent 25" without needing to read the ledger.
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
    <div className="rounded-xl border border-[var(--color-line)] bg-[var(--color-raised)] p-5 transition-colors hover:border-[var(--color-line)]/80">
      <div className="flex items-center gap-2.5">
        <Avatar name={cat.name} size={26} />
        <span className="text-sm font-medium">{cat.name}</span>
      </div>

      <div className="mt-4 flex items-baseline gap-1.5">
        <span className="tabular text-[28px] leading-none font-semibold tracking-tight">
          {formatTreats(cat.balance)}
        </span>
        <span className="text-xs text-[var(--color-muted)]">treats</span>

        {/* Reserved space, so the row does not jump when a delta appears. */}
        <span className="ml-auto h-4 text-xs font-medium">
          {delta !== null && (
            <span
              className="tabular"
              style={{
                color: delta > 0 ? "var(--color-accent)" : "var(--color-warn)",
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
    <div className="h-[118px] animate-pulse rounded-xl border border-[var(--color-line)] bg-[var(--color-raised)]" />
  );
}
