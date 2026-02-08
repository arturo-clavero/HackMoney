"use client";

import { use } from "react";
import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";
import { useReadContract, useReadContracts } from "wagmi";
import { useSearchParams } from "next/navigation";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import { softPegAbi } from "@/contracts/abis/softPeg";
import {
  getContractAddress,
  ARC_CHAIN_ID,
} from "@/contracts/addresses";
import { erc20Abi, type Address } from "viem";
import { InstanceOverview } from "@/components/instance/InstanceOverview";
import { UserManagement } from "@/components/instance/UserManagement";
import { VaultOperations } from "@/components/instance/VaultOperations";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { PageTransition, motion } from "@/components/motion";

type PegType = "hard" | "medium" | "soft";

export default function InstancePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const { open } = useAppKit();
  const { isConnected } = useAppKitAccount();
  const searchParams = useSearchParams();

  const pegType = (searchParams.get("peg") ?? "hard") as PegType;
  const chainId = Number(searchParams.get("chain") ?? ARC_CHAIN_ID);

  const addresses = getContractAddress(chainId);
 const contractAddress = pegType === "medium" ? addresses?.mediumPeg : pegType === "hard" ? addresses?.hardPeg : addresses?.softPeg;
const abi = pegType === "medium" ? mediumPegAbi : pegType === "hard" ? hardPegAbi : softPegAbi;
  let appId: bigint | undefined;
  try {
    appId = BigInt(id);
  } catch {
    return (
      <div className="mx-auto max-w-3xl px-6 py-12">
        <Alert variant="destructive">
          <AlertDescription>Invalid instance ID.</AlertDescription>
        </Alert>
        <Button variant="ghost" size="sm" asChild className="mt-4">
          <Link href="/">Back to Home</Link>
        </Button>
      </div>
    );
  }

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi,
    functionName: "getAppConfig",
    args: [appId!],
    chainId,
    query: { enabled: !!contractAddress && appId !== undefined, staleTime: 30_000 },
  });

  const coinAddress = appConfig?.coin as Address | undefined;

  const coinReads = useReadContracts({
    contracts: coinAddress
      ? [
          { address: coinAddress, abi: erc20Abi, functionName: "name" as const, chainId },
          { address: coinAddress, abi: erc20Abi, functionName: "symbol" as const, chainId },
        ]
      : [],
    query: { enabled: !!coinAddress, staleTime: 30_000 },
  });

  const coinName = coinReads.data?.[0]?.result as string | undefined;
  const coinSymbol = coinReads.data?.[1]?.result as string | undefined;
  const title = coinSymbol ? `${coinName ?? coinSymbol} (${coinSymbol})` : `Instance #${id}`;

  if (!isConnected) {
    return (
      <div className="flex min-h-[calc(100vh-57px)] items-center justify-center">
        <div className="flex flex-col items-center gap-6">
          <h1 className="text-2xl font-bold">{title}</h1>
          <p className="text-muted-foreground">
            Connect your wallet to view this instance.
          </p>
          <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
            <Button size="lg" onClick={() => open()}>
              Connect Wallet
            </Button>
          </motion.div>
        </div>
      </div>
    );
  }

  return (
    <PageTransition>
      <div className="mx-auto max-w-3xl px-6 py-12">
        <div className="mb-8 flex items-center gap-4">
          <Button variant="ghost" size="sm" asChild>
            <Link href="/">&larr; Back</Link>
          </Button>
          <h1 className="text-2xl font-bold">{title}</h1>
        </div>
        <div className="flex flex-col gap-8">
          <InstanceOverview appId={appId} pegType={pegType} chainId={chainId} />
          <UserManagement appId={appId} pegType={pegType} chainId={chainId} />
          <VaultOperations appId={appId} pegType={pegType} chainId={chainId} />
        </div>
      </div>
    </PageTransition>
  );
}
