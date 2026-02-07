"use client";

import { useWizard, type WizardStep } from "./WizardContext";
import { Stepper } from "./Stepper";
import { StepName } from "./StepName";
import { StepPegStyle } from "./StepPegStyle";
import { StepCollateral } from "./StepCollateral";
import { StepPermissions } from "./StepPermissions";
import { StepReview } from "./StepReview";
import { StepDeploy } from "./StepDeploy";
import { Button } from "@/components/ui/button";
import { SlideTransition } from "@/components/motion";

const STEP_COMPONENTS: Record<WizardStep, React.FC> = {
  0: StepName,
  1: StepPegStyle,
  2: StepCollateral,
  3: StepPermissions,
  4: StepReview,
  5: StepDeploy,
};

export function WizardLayout() {
  const { step, setStep, canProceed, direction } = useWizard();
  const StepComponent = STEP_COMPONENTS[step];

  return (
    <div className="w-full max-w-2xl mx-auto">
      <Stepper />
      <div className="min-h-[400px]">
        <SlideTransition direction={direction} stepKey={step}>
          <StepComponent />
        </SlideTransition>
      </div>
      {step < 5 && (
        <div className="flex justify-between mt-8">
          <Button
            variant="ghost"
            onClick={() => setStep((step - 1) as WizardStep)}
            disabled={step === 0}
            className={step === 0 ? "invisible" : ""}
          >
            Back
          </Button>
          <Button
            onClick={() => setStep((step + 1) as WizardStep)}
            disabled={!canProceed}
          >
            {step === 4 ? "Deploy Instance" : "Next"}
          </Button>
        </div>
      )}
    </div>
  );
}
