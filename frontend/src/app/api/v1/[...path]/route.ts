import { NextResponse } from 'next/server';

/**
 * Proxies read requests through to the ledger API.
 *
 * This is a route handler rather than a `rewrites()` entry in next.config, and the
 * difference is not stylistic. `rewrites()` is evaluated at **build** time and its
 * destination is baked into the routes manifest, so `process.env.API_URL` would be read
 * while the image was being built -- where it is unset -- and every container would then
 * try to reach localhost regardless of what the environment said. A route handler runs
 * per request, so the variable is read when it is actually needed and one image can be
 * pointed at any backend.
 *
 * Proxying at all keeps the browser talking only to this origin: no CORS policy is
 * needed on the backend, and the API's location never reaches the client bundle.
 */
export const dynamic = 'force-dynamic';

const API_URL = () => process.env.API_URL ?? 'http://localhost:8080';

export async function GET(
  request: Request,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const { search } = new URL(request.url);
  const target = `${API_URL()}/api/v1/${path.join('/')}${search}`;

  try {
    const upstream = await fetch(target, {
      headers: { Accept: 'application/json' },
      cache: 'no-store',
    });

    // Status and body pass through untouched, so the client still sees the API's own
    // RFC 9457 problem documents rather than a generic proxy error.
    return new NextResponse(upstream.body, {
      status: upstream.status,
      headers: {
        'Content-Type': upstream.headers.get('Content-Type') ?? 'application/json',
      },
    });
  } catch {
    // The API is unreachable, which is distinct from the API returning an error.
    // 502 says so honestly instead of reporting this app as broken.
    return NextResponse.json(
      {
        type: 'https://meowpay.co/problems/upstream-unavailable',
        title: 'Ledger API is unreachable',
        status: 502,
      },
      { status: 502 },
    );
  }
}
