"use client";

import { useAppKit, useAppKitAccount } from "@reown/appkit/react";

export default function Home() {
  const { open } = useAppKit();
  const { address, isConnected } = useAppKitAccount();

  return (
    <div className="flex min-h-screen items-center justify-center bg-zinc-50 font-sans dark:bg-black">
      <main className="flex min-h-screen w-full max-w-3xl flex-col items-center justify-center gap-8 py-32 px-16 bg-white dark:bg-black">
        <h1 className="text-4xl font-bold text-black dark:text-white">
          HackMoney
        </h1>

        {isConnected ? (
          <div className="flex flex-col items-center gap-4">
            <p className="text-zinc-600 dark:text-zinc-400">Connected as:</p>
            <code className="rounded-lg bg-zinc-100 px-4 py-2 text-sm dark:bg-zinc-800">
              {address}
            </code>
            <button
              onClick={() => open({ view: "Account" })}
              className="rounded-full bg-zinc-200 px-6 py-3 font-medium text-black transition-colors hover:bg-zinc-300 dark:bg-zinc-800 dark:text-white dark:hover:bg-zinc-700"
            >
              View Account
            </button>
          </div>
        ) : (
          <button
            onClick={() => open()}
            className="rounded-full bg-blue-600 px-8 py-4 text-lg font-medium text-white transition-colors hover:bg-blue-700"
          >
            Connect Wallet
          </button>
        )}
      </main>
    </div>
  );
}
