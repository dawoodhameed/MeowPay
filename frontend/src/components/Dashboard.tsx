'use client';

import { api, type Cat, type LedgerPage } from '@/lib/api';
import { usePolling } from '@/lib/usePolling';
import { LedgerTable } from './LedgerTable';
import { WalletCard, WalletCardSkeleton } from './WalletCard';

const POLL_MS = 3000;

export function Dashboard() {
  const cats = usePolling<Cat[]>((signal) => api.listCats(signal), POLL_MS);
  const ledger = usePolling<LedgerPage>((signal) => api.listTransfers(25, signal), POLL_MS);

  // Only a first load that failed leaves nothing to show. Once data has arrived, a
  // failed poll keeps the last good view rather than replacing it with an error.
  const fatal = (cats.error && !cats.data) || (ledger.error && !ledger.data);
  const stale = Boolean(cats.error || ledger.error);

  return (
    <main className="mx-auto max-w-4xl px-6 py-12">
      <header className="flex items-end justify-between gap-4">
        <div>
          <h1 className="text-lg font-semibold tracking-tight">MeowPay Ledger</h1>
          <p className="mt-1 text-sm text-[var(--color-muted)]">
            Every treat that has moved between cats.
          </p>
        </div>
        <StatusPill stale={stale} lastUpdated={ledger.lastUpdated} />
      </header>

      {fatal ? (
        <ConnectionError onRetry={() => {
          cats.refresh();
          ledger.refresh();
        }} />
      ) : (
        <>
          <section className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {cats.loading && !cats.data
              ? [0, 1, 2].map((i) => <WalletCardSkeleton key={i} />)
              : cats.data?.map((cat) => <WalletCard key={cat.id} cat={cat} />)}
          </section>

          <section className="mt-10 overflow-hidden rounded-xl border border-[var(--color-line)] bg-[var(--color-surface)]">
            <div className="flex items-center justify-between border-b border-[var(--color-line)] px-5 py-3">
              <h2 className="text-sm font-medium">Transactions</h2>
              {ledger.data && (
                <span className="tabular text-xs text-[var(--color-muted)]">
                  {ledger.data.items.length}
                  {ledger.data.nextCursor ? '+' : ''} shown
                </span>
              )}
            </div>
            {ledger.loading && !ledger.data ? (
              <div className="px-5 py-14 text-center text-sm text-[var(--color-muted)]">
                Loading ledger…
              </div>
            ) : (
              <LedgerTable entries={ledger.data?.items ?? []} />
            )}
          </section>
        </>
      )}
    </main>
  );
}

function StatusPill({ stale, lastUpdated }: { stale: boolean; lastUpdated: Date | null }) {
  return (
    <div className="flex items-center gap-2 text-xs text-[var(--color-muted)]">
      <span
        className={`h-1.5 w-1.5 rounded-full ${
          stale ? 'bg-[var(--color-debit)]' : 'animate-pulse bg-[var(--color-credit)]'
        }`}
      />
      {stale ? 'Reconnecting…' : lastUpdated ? `Updated ${lastUpdated.toLocaleTimeString()}` : 'Live'}
    </div>
  );
}

function ConnectionError({ onRetry }: { onRetry: () => void }) {
  return (
    <div className="mt-10 rounded-xl border border-[var(--color-debit)]/30 bg-[var(--color-debit)]/5 px-5 py-8 text-center">
      <p className="text-sm font-medium text-[var(--color-text)]">Cannot reach the ledger API</p>
      <p className="mx-auto mt-1 max-w-sm text-xs text-[var(--color-muted)]">
        The backend is not responding. Check that it is running, then try again.
      </p>
      <button
        onClick={onRetry}
        className="mt-4 rounded-lg border border-[var(--color-line)] px-3 py-1.5 text-xs text-[var(--color-text)] hover:bg-white/5 focus-visible:ring-2 focus-visible:ring-[var(--color-credit)] focus-visible:outline-none"
      >
        Retry
      </button>
    </div>
  );
}
