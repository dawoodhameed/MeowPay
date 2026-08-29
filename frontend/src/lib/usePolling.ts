"use client";

import { useCallback, useEffect, useRef, useState } from "react";

type PollingState<T> = {
  data: T | null;
  error: Error | null;
  /** True only for the first load, so refreshes do not blank the screen. */
  loading: boolean;
  lastUpdated: Date | null;
};

/**
 * Re-fetches on an interval.
 *
 * Polling rather than a websocket is a deliberate scope decision: a socket would add
 * a connection lifecycle, reconnect logic and a delivery-guarantee problem to a
 * read-only view where a second of staleness costs nothing.
 *
 * Two details keep it from being visibly worse than a socket. An in-flight request is
 * aborted when the next one starts or the component unmounts, so a slow response can
 * never overwrite a newer one. And a failed poll keeps the last good data on screen
 * instead of replacing the ledger with an error -- the next tick usually recovers.
 */
export function usePolling<T>(
  fetcher: (signal: AbortSignal) => Promise<T>,
  intervalMs: number,
): PollingState<T> & { refresh: () => void } {
  const [state, setState] = useState<PollingState<T>>({
    data: null,
    error: null,
    loading: true,
    lastUpdated: null,
  });

  const controllerRef = useRef<AbortController | null>(null);
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;

  const load = useCallback(async () => {
    controllerRef.current?.abort();
    const controller = new AbortController();
    controllerRef.current = controller;

    try {
      const data = await fetcherRef.current(controller.signal);
      setState({ data, error: null, loading: false, lastUpdated: new Date() });
    } catch (error) {
      if (controller.signal.aborted) return;
      setState((prev) => ({
        ...prev,
        error: error instanceof Error ? error : new Error("Request failed"),
        loading: false,
      }));
    }
  }, []);

  useEffect(() => {
    load();
    const timer = setInterval(load, intervalMs);
    return () => {
      clearInterval(timer);
      controllerRef.current?.abort();
    };
  }, [load, intervalMs]);

  return { ...state, refresh: load };
}
