"use client";

import { useAppKitAccount } from "@reown/appkit/react";
import { WizardProvider } from "@/components/create/WizardContext";
import { WizardLayout } from "@/components/create/WizardLayout";
import { PageTransition } from "@/components/motion";

export default function CreatePage() {
  const { isConnected } = useAppKitAccount();

  if (!isConnected) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <p className="text-muted-foreground">
          Connect your wallet to create a stablecoin instance.
        </p>
      </div>
    );
  }

  return (
    <PageTransition>
      <div className="flex min-h-screen flex-col items-center px-6 py-16">
        <h1 className="text-2xl font-bold mb-2">
          Create Stablecoin Instance
        </h1>
        <p className="text-muted-foreground mb-10 text-center max-w-md">
          Deploy your own stablecoin backed by protocol-approved collateral.
        </p>
        <WizardProvider>
          <WizardLayout />
        </WizardProvider>
      </div>
    </PageTransition>
  );
}
