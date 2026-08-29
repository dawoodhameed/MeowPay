"use client";

import { createContext, useContext, useMemo, type ReactNode } from "react";
import { AVATAR_COLORS, fallbackAvatarColor } from "@/lib/format";

const CatColorContext = createContext<Map<
  string,
  (typeof AVATAR_COLORS)[number]
> | null>(null);

/**
 * Assigns each cat a colour by its position in the (name-sorted) list, so the palette
 * is distinct across everyone currently on screen and stable between renders.
 *
 * Hashing the name instead looks equivalent and is not: across a handful of names,
 * collisions are likely rather than rare -- "Whiskers" and "Mittens" collided -- and
 * two cats sharing a colour makes the ledger harder to scan than no colour at all.
 */
export function CatColorProvider({
  names,
  children,
}: {
  names: string[];
  children: ReactNode;
}) {
  const map = useMemo(() => {
    const sorted = [...new Set(names)].sort();
    return new Map(
      sorted.map((name, i) => [name, AVATAR_COLORS[i % AVATAR_COLORS.length]]),
    );
  }, [names]);

  return (
    <CatColorContext.Provider value={map}>{children}</CatColorContext.Provider>
  );
}

export function useCatColor(name: string) {
  const map = useContext(CatColorContext);
  return map?.get(name) ?? fallbackAvatarColor(name);
}
