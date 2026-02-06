"use client";

import { useWizard, type PegStyle } from "./WizardContext";

interface PegOption {
  id: PegStyle;
  title: string;
  description: string;
  accepts: string;
  enabled: boolean;
}

const PEG_OPTIONS: PegOption[] = [
  {
    id: "hard",
    title: "Hard Peg",
    description:
      "Backed 1:1 by stablecoins. Deposit one stablecoin, mint yours. Simple and predictable \u2014 what goes in is what comes out.",
    accepts: "Stablecoins",
    enabled: true,
  },
  {
    id: "yield",
    title: "Yield Peg",
    description:
      "Backed by yield-bearing assets like vault tokens. Your collateral earns yield while it sits behind your stablecoin.",
    accepts: "Yield-bearing tokens",
    enabled: false,
  },
  {
    id: "soft",
    title: "Soft Peg",
    description:
      "Backed by volatile assets like ETH or BTC. More capital flexible, but requires overcollateralization and carries liquidation risk.",
    accepts: "Volatile assets",
    enabled: false,
  },
];

export function StepPegStyle() {
  const { state, setState } = useWizard();

  const select = (id: PegStyle) => {
    if (id === state.pegStyle) return;
    setState({ pegStyle: id, selectedCollateral: [] });
  };

  return (
    <div className="flex flex-col gap-4">
      {PEG_OPTIONS.map((opt) => {
        const isSelected = state.pegStyle === opt.id;
        return (
          <button
            key={opt.id}
            disabled={!opt.enabled}
            onClick={() => select(opt.id)}
            className={`relative flex flex-col gap-2 rounded-xl border p-5 text-left transition-colors ${
              !opt.enabled
                ? "cursor-not-allowed opacity-50 border-zinc-200 dark:border-zinc-800"
                : isSelected
                  ? "border-blue-500 bg-blue-50 dark:bg-blue-950"
                  : "border-zinc-200 hover:border-zinc-300 dark:border-zinc-800 dark:hover:border-zinc-700"
            }`}
          >
            <div className="flex items-center gap-3">
              <div
                className={`h-5 w-5 shrink-0 rounded-full border-2 flex items-center justify-center ${
                  isSelected
                    ? "border-blue-600"
                    : "border-zinc-300 dark:border-zinc-600"
                }`}
              >
                {isSelected && (
                  <div className="h-2.5 w-2.5 rounded-full bg-blue-600" />
                )}
              </div>
              <h3 className="text-lg font-semibold text-black dark:text-white">
                {opt.title}
              </h3>
              {!opt.enabled && (
                <span className="rounded-full bg-zinc-200 px-2.5 py-0.5 text-xs font-medium text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400">
                  Coming Soon
                </span>
              )}
            </div>
            <p className="text-sm text-zinc-500 dark:text-zinc-400 ml-8">
              {opt.description}
            </p>
            <p className="text-xs text-zinc-400 dark:text-zinc-500 ml-8">
              Accepts: {opt.accepts}
            </p>
          </button>
        );
      })}
    </div>
  );
}
