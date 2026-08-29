export type Cat = {
  id: string;
  name: string;
  avatarUrl: string | null;
  walletId: string;
  balance: number;
};

export type LedgerParty = {
  walletId: string;
  catName: string;
};

export type LedgerEntry = {
  id: string;
  amount: number;
  status: string;
  createdAt: string;
  sender: LedgerParty;
  recipient: LedgerParty;
};

export type LedgerPage = {
  items: LedgerEntry[];
  nextCursor: string | null;
};

/**
 * Shape of an RFC 9457 problem response. The API returns these for every failure,
 * so errors carry a machine-readable `type` rather than a message to match on.
 */
export type ApiProblem = {
  type: string;
  title: string;
  status: number;
  detail?: string;
};

export class ApiError extends Error {
  constructor(
    readonly problem: ApiProblem,
    readonly status: number,
  ) {
    super(problem.title);
  }
}

// Relative, so the request goes to this app and Next proxies it onward. Nothing
// here needs to know where the backend lives.
const BASE = '/api/v1';

async function get<T>(path: string, signal?: AbortSignal): Promise<T> {
  const response = await fetch(`${BASE}${path}`, {
    signal,
    headers: { Accept: 'application/json' },
    cache: 'no-store',
  });

  if (!response.ok) {
    // A failing endpoint should still say what went wrong. If the body is not a
    // problem document -- a proxy timeout, say -- synthesise one so callers have a
    // single error shape to handle.
    const problem: ApiProblem = await response.json().catch(() => ({
      type: 'about:blank',
      title: `Request failed (${response.status})`,
      status: response.status,
    }));
    throw new ApiError(problem, response.status);
  }

  return response.json() as Promise<T>;
}

export const api = {
  listCats: (signal?: AbortSignal) => get<Cat[]>('/cats', signal),
  listTransfers: (limit = 25, signal?: AbortSignal) =>
    get<LedgerPage>(`/transfers?limit=${limit}`, signal),
};
