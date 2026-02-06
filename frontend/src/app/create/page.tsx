"use client";

import { useAppKitAccount } from "@reown/appkit/react";
import { WizardProvider } from "@/components/create/WizardContext";
import { WizardLayout } from "@/components/create/WizardLayout";

export default function CreatePage() {
  const { isConnected } = useAppKitAccount();

  if (!isConnected) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-zinc-500">Connect your wallet to create a stablecoin instance.</p>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen flex-col items-center px-6 py-16">
      <h1 className="text-2xl font-bold mb-2 text-black dark:text-white">
        Create Stablecoin Instance
      </h1>
      <p className="text-zinc-500 mb-10 text-center max-w-md">
        Deploy your own stablecoin backed by protocol-approved collateral.
      </p>
      <WizardProvider>
        <WizardLayout />
      </WizardProvider>
    </div>
  );
}
