"use client";

import { useWizard } from "./WizardContext";
import { useAppKitAccount } from "@reown/appkit/react";

export function StepName() {
  const { state, setState } = useWizard();
  const { address } = useAppKitAccount();

  const symbolValid =
    state.tokenSymbol.length === 0 || /^[A-Za-z0-9]{2,5}$/.test(state.tokenSymbol);

  return (
    <div className="flex flex-col gap-8 sm:flex-row sm:gap-12">
      <div className="flex-1 flex flex-col gap-6">
        <div>
          <label className="block text-sm font-medium mb-2 text-black dark:text-white">
            Token Name
          </label>
          <input
            type="text"
            placeholder="e.g. SalaryCoin"
            value={state.tokenName}
            onChange={(e) => setState({ tokenName: e.target.value })}
            className="w-full rounded-lg border border-zinc-300 bg-white px-4 py-3 text-black outline-none transition-colors focus:border-blue-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
          />
        </div>
        <div>
          <label className="block text-sm font-medium mb-2 text-black dark:text-white">
            Token Symbol
          </label>
          <input
            type="text"
            placeholder="e.g. SAL"
            maxLength={5}
            value={state.tokenSymbol}
            onChange={(e) =>
              setState({ tokenSymbol: e.target.value.toUpperCase() })
            }
            className={`w-full rounded-lg border bg-white px-4 py-3 text-black outline-none transition-colors focus:border-blue-500 dark:bg-zinc-900 dark:text-white ${
              symbolValid
                ? "border-zinc-300 dark:border-zinc-700"
                : "border-red-500"
            }`}
          />
          {!symbolValid && (
            <p className="mt-1 text-sm text-red-500">
              Symbol must be 2-5 alphanumeric characters.
            </p>
          )}
        </div>
        <div className="rounded-lg bg-blue-50 p-4 text-sm text-blue-800 dark:bg-blue-950 dark:text-blue-200">
          You&apos;re creating a new stablecoin instance on the protocol. Each
          instance gets its own ERC20 token that you control. Think of it like
          creating a branded dollar for your specific use case.
        </div>
      </div>

      {/* Live preview */}
      <div className="sm:w-56 shrink-0">
        <div className="rounded-xl border border-zinc-200 p-5 dark:border-zinc-800">
          <p className="text-xs text-zinc-400 mb-3 uppercase tracking-wider">
            Preview
          </p>
          <p className="text-lg font-semibold text-black dark:text-white">
            {state.tokenName || "Token Name"}
          </p>
          <p className="text-sm text-zinc-500">
            {state.tokenSymbol || "SYM"}
          </p>
          <div className="mt-4 pt-4 border-t border-zinc-100 dark:border-zinc-800">
            <p className="text-xs text-zinc-400">Owner</p>
            <p className="text-xs text-zinc-600 dark:text-zinc-400 font-mono truncate">
              {address}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}
