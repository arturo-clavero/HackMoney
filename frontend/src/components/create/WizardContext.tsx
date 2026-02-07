"use client";

import { createContext, useContext, useState, type ReactNode } from "react";
import { type Address } from "viem";

export type PegStyle = "hard" | "yield" | "soft";
export type WizardStep = 0 | 1 | 2 | 3 | 4 | 5;

export interface WizardState {
  tokenName: string;
  tokenSymbol: string;
  pegStyle: PegStyle;
  selectedCollateral: Address[];
  usersCanMint: boolean;
}

interface WizardContextValue {
  step: WizardStep;
  setStep: (step: WizardStep) => void;
  state: WizardState;
  setState: (update: Partial<WizardState>) => void;
  canProceed: boolean;
  direction: number;
}

const WizardContext = createContext<WizardContextValue | null>(null);

const initialState: WizardState = {
  tokenName: "",
  tokenSymbol: "",
  pegStyle: "hard",
  selectedCollateral: [],
  usersCanMint: false,
};

export function WizardProvider({ children }: { children: ReactNode }) {
  const [step, setStepRaw] = useState<WizardStep>(0);
  const [direction, setDirection] = useState(1);
  const [state, setStateRaw] = useState<WizardState>(initialState);

  const setStep = (newStep: WizardStep) => {
    setDirection(newStep > step ? 1 : -1);
    setStepRaw(newStep);
  };

  const setState = (update: Partial<WizardState>) => {
    setStateRaw((prev) => ({ ...prev, ...update }));
  };

  const canProceed = (() => {
    switch (step) {
      case 0:
        return (
          state.tokenName.trim().length > 0 &&
          /^[A-Za-z0-9]{2,5}$/.test(state.tokenSymbol)
        );
      case 1:
        return !!state.pegStyle;
      case 2:
        return state.selectedCollateral.length > 0;
      case 3:
        return true;
      case 4:
        return true;
      default:
        return false;
    }
  })();

  return (
    <WizardContext.Provider
      value={{ step, setStep, state, setState, canProceed, direction }}
    >
      {children}
    </WizardContext.Provider>
  );
}

export function useWizard() {
  const ctx = useContext(WizardContext);
  if (!ctx) throw new Error("useWizard must be used within WizardProvider");
  return ctx;
}
