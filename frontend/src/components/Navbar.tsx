"use client";

import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";

export function Navbar() {
  const { open } = useAppKit();
  const { address, isConnected } = useAppKitAccount();

  return (
    <nav className="sticky top-0 z-50 flex items-center justify-between border-b border-zinc-200 bg-white/80 px-6 py-3 backdrop-blur dark:border-zinc-800 dark:bg-black/80">
      <Link href="/" className="text-lg font-bold text-black dark:text-white">
        HackMoney
      </Link>
      {isConnected ? (
        <button
          onClick={() => open({ view: "Account" })}
          className="rounded-lg bg-zinc-100 px-4 py-2 text-sm font-mono text-zinc-700 transition-colors hover:bg-zinc-200 dark:bg-zinc-800 dark:text-zinc-300 dark:hover:bg-zinc-700"
        >
          {address?.slice(0, 6)}...{address?.slice(-4)}
        </button>
      ) : (
        <button
          onClick={() => open()}
          className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700"
        >
          Connect
        </button>
      )}
    </nav>
  );
}
