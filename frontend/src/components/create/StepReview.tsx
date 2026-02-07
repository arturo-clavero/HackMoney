"use client";

import { useWizard, type WizardStep } from "./WizardContext";
import { useAppKitAccount } from "@reown/appkit/react";
import { Card, CardContent } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

interface ReviewRowProps {
  label: string;
  value: string;
  editStep?: WizardStep;
  onEdit?: (step: WizardStep) => void;
}

function ReviewRow({ label, value, editStep, onEdit }: ReviewRowProps) {
  return (
    <div className="flex items-start justify-between py-3">
      <div>
        <p className="text-sm text-muted-foreground">{label}</p>
        <p className="mt-0.5">{value}</p>
      </div>
      {editStep !== undefined && onEdit && (
        <Button
          variant="ghost"
          size="sm"
          onClick={() => onEdit(editStep)}
        >
          Edit
        </Button>
      )}
    </div>
  );
}

export function StepReview() {
  const { state, setStep } = useWizard();
  const { address } = useAppKitAccount();

  const userPermissions = [
    "Hold",
    "Receive Transfers",
    ...(state.usersCanMint ? ["Mint"] : []),
  ].join(", ");

  return (
    <div className="flex flex-col gap-6">
      <Card>
        <CardContent className="px-5 py-0">
          <ReviewRow
            label="Token"
            value={`${state.tokenName} (${state.tokenSymbol})`}
            editStep={0}
            onEdit={setStep}
          />
          <Separator />
          <ReviewRow
            label="Peg Style"
            value={
              state.pegStyle === "hard"
                ? "Hard Peg"
                : state.pegStyle === "yield"
                  ? "Yield Peg"
                  : "Soft Peg"
            }
            editStep={1}
            onEdit={setStep}
          />
          <Separator />
          <ReviewRow
            label="Owner"
            value={address ? truncateAddress(address) : "Not connected"}
          />
          <Separator />
          <ReviewRow
            label="Collateral"
            value={state.selectedCollateral.map(truncateAddress).join(", ")}
            editStep={2}
            onEdit={setStep}
          />
          <Separator />
          <ReviewRow
            label="Owner can"
            value="Mint"
            editStep={3}
            onEdit={setStep}
          />
          <Separator />
          <ReviewRow
            label="Users can"
            value={userPermissions}
            editStep={3}
            onEdit={setStep}
          />
        </CardContent>
      </Card>

      <Alert>
        <AlertDescription>
          This will deploy a new ERC20 token contract and register it with the
          protocol. You&apos;ll be the owner and can add users afterwards.
        </AlertDescription>
      </Alert>
    </div>
  );
}
