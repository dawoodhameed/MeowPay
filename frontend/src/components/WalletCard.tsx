import type { Cat } from '@/lib/api';
import { formatTreats } from '@/lib/format';

export function WalletCard({ cat }: { cat: Cat }) {
  return (
    <div className="rounded-xl border border-[var(--color-line)] bg-[var(--color-raised)] p-5">
      <div className="flex items-center justify-between">
        <span className="text-sm font-medium text-[var(--color-text)]">{cat.name}</span>
        <span className="rounded-full border border-[var(--color-line)] px-2 py-0.5 font-mono text-[10px] text-[var(--color-muted)]">
          {cat.walletId.slice(0, 8)}
        </span>
      </div>
      <div className="mt-4 flex items-baseline gap-1.5">
        <span className="tabular text-3xl font-semibold tracking-tight text-[var(--color-text)]">
          {formatTreats(cat.balance)}
        </span>
        <span className="text-xs text-[var(--color-muted)]">treats</span>
      </div>
    </div>
  );
}

export function WalletCardSkeleton() {
  return (
    <div className="h-[116px] animate-pulse rounded-xl border border-[var(--color-line)] bg-[var(--color-raised)]" />
  );
}
