"use client";

import { initialOf } from "@/lib/format";
import { useCatColor } from "./CatColors";

export function Avatar({ name, size = 24 }: { name: string; size?: number }) {
  const { bg, fg } = useCatColor(name);
  return (
    <span
      aria-hidden
      className="inline-flex shrink-0 items-center justify-center rounded-full font-medium"
      style={{
        width: size,
        height: size,
        background: bg,
        color: fg,
        fontSize: size * 0.44,
      }}
    >
      {initialOf(name)}
    </span>
  );
}
