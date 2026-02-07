"use client";

import { useWizard, type PegStyle } from "./WizardContext";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";

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
          <Card
            key={opt.id}
            className={`cursor-pointer transition-colors ${
              !opt.enabled
                ? "cursor-not-allowed opacity-50"
                : isSelected
                  ? "border-primary bg-primary/5"
                  : "hover:border-muted-foreground/30"
            }`}
            onClick={() => opt.enabled && select(opt.id)}
          >
            <CardContent className="flex flex-col gap-2 p-5">
              <div className="flex items-center gap-3">
                <div
                  className={`h-5 w-5 shrink-0 rounded-full border-2 flex items-center justify-center ${
                    isSelected
                      ? "border-primary"
                      : "border-muted-foreground/30"
                  }`}
                >
                  {isSelected && (
                    <div className="h-2.5 w-2.5 rounded-full bg-primary" />
                  )}
                </div>
                <h3 className="text-lg font-semibold">{opt.title}</h3>
                {!opt.enabled && (
                  <Badge variant="secondary">Coming Soon</Badge>
                )}
              </div>
              <p className="text-sm text-muted-foreground ml-8">
                {opt.description}
              </p>
              <p className="text-xs text-muted-foreground/60 ml-8">
                Accepts: {opt.accepts}
              </p>
            </CardContent>
          </Card>
        );
      })}
    </div>
  );
}
