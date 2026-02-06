"use client";

import { use } from "react";
import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";
import { useReadContract, useReadContracts } from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { erc20Abi, type Address } from "viem";
import { InstanceOverview } from "@/components/instance/InstanceOverview";
import { UserManagement } from "@/components/instance/UserManagement";
import { VaultOperations } from "@/components/instance/VaultOperations";

export default function InstancePage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = use(params);
  const { open } = useAppKit();
  const { isConnected, caipAddress } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  let appId: bigint | undefined;
  try {
    appId = BigInt(id);
  } catch {
    return (
      <div className="mx-auto max-w-3xl px-6 py-12">
        <div className="rounded-lg bg-red-50 p-4 text-sm text-red-800 dark:bg-red-950 dark:text-red-200">
          Invalid instance ID.
        </div>
        <Link
          href="/"
          className="mt-4 inline-block text-sm text-blue-600 hover:underline"
        >
          Back to Home
        </Link>
      </div>
    );
  }

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId!],
    query: { enabled: !!contractAddress && appId !== undefined },
  });

  const coinAddress = appConfig?.coin as Address | undefined;

  const coinReads = useReadContracts({
    contracts: coinAddress
      ? [
          { address: coinAddress, abi: erc20Abi, functionName: "name" as const },
          { address: coinAddress, abi: erc20Abi, functionName: "symbol" as const },
        ]
      : [],
    query: { enabled: !!coinAddress },
  });

  const coinName = coinReads.data?.[0]?.result as string | undefined;
  const coinSymbol = coinReads.data?.[1]?.result as string | undefined;
  const title = coinSymbol ? `${coinName ?? coinSymbol} (${coinSymbol})` : `Instance #${id}`;

  if (!isConnected) {
    return (
      <div className="flex min-h-[calc(100vh-57px)] items-center justify-center">
        <div className="flex flex-col items-center gap-6">
          <h1 className="text-2xl font-bold text-black dark:text-white">
            {title}
          </h1>
          <p className="text-zinc-500">
            Connect your wallet to view this instance.
          </p>
          <button
            onClick={() => open()}
            className="rounded-lg bg-blue-600 px-8 py-4 text-lg font-medium text-white transition-colors hover:bg-blue-700"
          >
            Connect Wallet
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-3xl px-6 py-12">
      <div className="mb-8 flex items-center gap-4">
        <Link
          href="/"
          className="text-sm text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300"
        >
          &larr; Back
        </Link>
        <h1 className="text-2xl font-bold text-black dark:text-white">
          {title}
        </h1>
      </div>
      <div className="flex flex-col gap-8">
        <InstanceOverview appId={appId} />
        <UserManagement appId={appId} />
        <VaultOperations appId={appId} />
      </div>
    </div>
  );
}
