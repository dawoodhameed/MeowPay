"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { api, type Cat, type LedgerPage } from "@/lib/api";
import { formatTreats } from "@/lib/format";
import { usePolling } from "@/lib/usePolling";
import { CatColorProvider } from "./CatColors";
import { LedgerTable } from "./LedgerTable";
import { WalletCard, WalletCardSkeleton } from "./WalletCard";

const POLL_MS = 3000;

export function Dashboard() {
  const cats = usePolling<Cat[]>((signal) => api.listCats(signal), POLL_MS);
  const ledger = usePolling<LedgerPage>(
    (signal) => api.listTransfers(25, signal),
    POLL_MS,
  );

  const newIds = useRecentlyArrived(ledger.data?.items.map((item) => item.id));
  const now = useTicker();

  // Only a first load that failed leaves nothing to show. Once data has arrived a
  // failed poll keeps the last good view rather than replacing it with an error.
  const fatal = (cats.error && !cats.data) || (ledger.error && !ledger.data);
  const degraded = Boolean(cats.error || ledger.error);

  const totalTreats = useMemo(
    () => cats.data?.reduce((sum, cat) => sum + cat.balance, 0) ?? null,
    [cats.data],
  );

  const catNames = useMemo(
    () => cats.data?.map((cat) => cat.name) ?? [],
    [cats.data],
  );

  return (
    <CatColorProvider names={catNames}>
      <main className="mx-auto max-w-3xl px-6 py-14">
        <header className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <h1 className="text-[19px] font-semibold tracking-tight">
              MeowPay Ledger
            </h1>
            <p className="mt-1 text-sm text-[var(--color-slate)]">
              Every treat that has moved between cats.
            </p>
          </div>
          <LiveIndicator
            degraded={degraded}
            lastUpdated={ledger.lastUpdated}
            now={now}
          />
        </header>

        {fatal ? (
          <ConnectionError
            onRetry={() => {
              cats.refresh();
              ledger.refresh();
            }}
          />
        ) : (
          <>
            <section className="mt-9 grid gap-3 sm:grid-cols-3">
              {!cats.data
                ? [0, 1, 2].map((i) => <WalletCardSkeleton key={i} />)
                : cats.data.map((cat) => <WalletCard key={cat.id} cat={cat} />)}
            </section>

            {/* The ledger's defining property is that treats are only ever moved, never
              created or destroyed. Showing the total makes that invariant something the
              reader can watch hold, instead of something they have to take on trust. */}
            {totalTreats !== null && (
              <p className="mt-3 text-xs text-[var(--color-slate)]">
                <span className="tabular font-bold text-[var(--color-navy)]">
                  {formatTreats(totalTreats)}
                </span>{" "}
                treats in circulation — constant, since transfers move treats
                rather than create them.
              </p>
            )}

            <section className="mt-9 overflow-hidden rounded-2xl border border-[var(--color-line)] bg-[var(--color-surface)]">
              <div className="flex items-center justify-between border-b border-[var(--color-line)] px-5 py-3">
                <h2 className="text-sm font-bold">Transactions</h2>
                {ledger.data && ledger.data.items.length > 0 && (
                  <span className="tabular text-xs text-[var(--color-slate)]">
                    {ledger.data.items.length}
                    {ledger.data.nextCursor ? "+" : ""}
                  </span>
                )}
              </div>
              {!ledger.data ? (
                <div className="px-5 py-16 text-center text-sm text-[var(--color-slate)]">
                  Loading ledger…
                </div>
              ) : (
                <LedgerTable
                  entries={ledger.data.items}
                  newIds={newIds}
                  now={now}
                />
              )}
            </section>
          </>
        )}
      </main>
    </CatColorProvider>
  );
}

/**
 * Ids seen for the first time since the last poll, so a new row can announce itself.
 * The very first load is excluded -- highlighting the whole table on arrival would
 * signal nothing.
 */
function useRecentlyArrived(ids: string[] | undefined): Set<string> {
  const seen = useRef<Set<string> | null>(null);
  const [fresh, setFresh] = useState<Set<string>>(new Set());

  useEffect(() => {
    if (!ids) return;

    if (seen.current === null) {
      seen.current = new Set(ids);
      return;
    }

    const arrived = ids.filter((id) => !seen.current!.has(id));
    ids.forEach((id) => seen.current!.add(id));
    if (arrived.length === 0) return;

    setFresh(new Set(arrived));
    const timer = setTimeout(() => setFresh(new Set()), 2000);
    return () => clearTimeout(timer);
  }, [ids]);

  return fresh;
}

/** Drives relative timestamps so "12s ago" keeps counting between polls. */
function useTicker(intervalMs = 1000): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), intervalMs);
    return () => clearInterval(timer);
  }, [intervalMs]);
  return now;
}

function LiveIndicator({
  degraded,
  lastUpdated,
  now,
}: {
  degraded: boolean;
  lastUpdated: Date | null;
  now: number;
}) {
  const secondsAgo = lastUpdated
    ? Math.round((now - lastUpdated.getTime()) / 1000)
    : null;

  return (
    <div className="flex items-center gap-2 rounded-full border border-[var(--color-line)] bg-[var(--color-surface)] px-2.5 py-1 text-xs text-[var(--color-slate)]">
      <span className="relative flex h-1.5 w-1.5">
        {!degraded && (
          <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[var(--color-positive)] opacity-60" />
        )}
        <span
          className="relative inline-flex h-1.5 w-1.5 rounded-full"
          style={{
            background: degraded
              ? "var(--color-coral)"
              : "var(--color-positive)",
          }}
        />
      </span>
      {degraded
        ? "Reconnecting"
        : secondsAgo === null
          ? "Connecting"
          : `Live · ${secondsAgo}s ago`}
    </div>
  );
}

function ConnectionError({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="mt-10 rounded-2xl bg-[var(--color-blush)] px-5 py-10 text-center">
      <p className="text-sm font-bold">Cannot reach the ledger API</p>
      <p className="mx-auto mt-1.5 max-w-sm text-xs leading-relaxed text-[var(--color-slate)]">
        The backend is not responding. Check that it is running, then try again.
      </p>
      <button
        onClick={onRetry}
        className="mt-5 rounded-xl bg-[var(--color-coral)] px-4 py-2 text-xs font-bold text-white transition-opacity hover:opacity-90 focus-visible:ring-2 focus-visible:ring-[var(--color-coral)] focus-visible:ring-offset-2 focus-visible:outline-none"
      >
        Retry now
      </button>
    </div>
  );
}
