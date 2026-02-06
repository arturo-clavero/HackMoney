"use client";

import { useWizard, type WizardStep } from "./WizardContext";
import { Stepper } from "./Stepper";
import { StepName } from "./StepName";
import { StepPegStyle } from "./StepPegStyle";
import { StepCollateral } from "./StepCollateral";
import { StepPermissions } from "./StepPermissions";
import { StepReview } from "./StepReview";
import { StepDeploy } from "./StepDeploy";

const STEP_COMPONENTS: Record<WizardStep, React.FC> = {
  0: StepName,
  1: StepPegStyle,
  2: StepCollateral,
  3: StepPermissions,
  4: StepReview,
  5: StepDeploy,
};

export function WizardLayout() {
  const { step, setStep, canProceed } = useWizard();
  const StepComponent = STEP_COMPONENTS[step];

  return (
    <div className="w-full max-w-2xl mx-auto">
      <Stepper />
      <div className="min-h-[400px]">
        <StepComponent />
      </div>
      {step < 5 && (
        <div className="flex justify-between mt-8">
          <button
            onClick={() => setStep((step - 1) as WizardStep)}
            disabled={step === 0}
            className="rounded-lg px-6 py-3 text-sm font-medium text-zinc-600 transition-colors hover:text-black disabled:invisible dark:text-zinc-400 dark:hover:text-white"
          >
            Back
          </button>
          <button
            onClick={() => setStep((step + 1) as WizardStep)}
            disabled={!canProceed}
            className="rounded-lg bg-blue-600 px-6 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {step === 4 ? "Deploy Instance" : "Next"}
          </button>
        </div>
      )}
    </div>
  );
}
