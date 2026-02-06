"use client";

import { useWizard, type WizardStep } from "./WizardContext";
import { useAppKitAccount } from "@reown/appkit/react";

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
        <p className="text-sm text-zinc-400">{label}</p>
        <p className="text-black dark:text-white mt-0.5">{value}</p>
      </div>
      {editStep !== undefined && onEdit && (
        <button
          onClick={() => onEdit(editStep)}
          className="text-sm text-blue-600 hover:text-blue-700"
        >
          Edit
        </button>
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
      <div className="rounded-xl border border-zinc-200 divide-y divide-zinc-100 px-5 dark:border-zinc-800 dark:divide-zinc-800">
        <ReviewRow
          label="Token"
          value={`${state.tokenName} (${state.tokenSymbol})`}
          editStep={0}
          onEdit={setStep}
        />
        <ReviewRow
          label="Peg Style"
          value={state.pegStyle === "hard" ? "Hard Peg" : state.pegStyle === "yield" ? "Yield Peg" : "Soft Peg"}
          editStep={1}
          onEdit={setStep}
        />
        <ReviewRow
          label="Owner"
          value={address ? truncateAddress(address) : "Not connected"}
        />
        <ReviewRow
          label="Collateral"
          value={state.selectedCollateral.map(truncateAddress).join(", ")}
          editStep={2}
          onEdit={setStep}
        />
        <ReviewRow
          label="Owner can"
          value="Mint"
          editStep={3}
          onEdit={setStep}
        />
        <ReviewRow
          label="Users can"
          value={userPermissions}
          editStep={3}
          onEdit={setStep}
        />
      </div>

      <div className="rounded-lg bg-blue-50 p-4 text-sm text-blue-800 dark:bg-blue-950 dark:text-blue-200">
        This will deploy a new ERC20 token contract and register it with the
        protocol. You&apos;ll be the owner and can add users afterwards.
      </div>
    </div>
  );
}
