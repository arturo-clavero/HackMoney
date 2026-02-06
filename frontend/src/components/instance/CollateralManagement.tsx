"use client";

import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { erc20Abi, type Address } from "viem";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function CollateralManagement({ appId }: { appId: bigint }) {
  const { caipAddress, address } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  // Read app config to determine owner
  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId],
    query: { enabled: !!contractAddress },
  });

  const owner = appConfig?.owner as Address | undefined;
  const isOwner =
    !!address && !!owner && address.toLowerCase() === owner.toLowerCase();

  // Fetch global collateral list
  const { data: collateralList } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getGlobalCollateralList",
    query: { enabled: !!contractAddress },
  });

  // Check which are allowed for this app
  const allowedChecks = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "isAppCollateralAllowed" as const,
      args: [appId, token] as const,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  // Fetch ERC20 name/symbol per token
  const tokenNames = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "name" as const,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  const tokenSymbols = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "symbol" as const,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  const { writeContract, isPending, data: txHash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  // Count enabled collateral
  const enabledCount = (collateralList ?? []).filter(
    (_, i) => allowedChecks.data?.[i]?.result === true
  ).length;

  const handleToggle = (token: Address, currentlyEnabled: boolean) => {
    if (!contractAddress) return;
    if (currentlyEnabled) {
      writeContract({
        address: contractAddress,
        abi: hardPegAbi,
        functionName: "removeAppCollateral",
        args: [appId, token],
      });
    } else {
      writeContract({
        address: contractAddress,
        abi: hardPegAbi,
        functionName: "addAppCollateral",
        args: [appId, token],
      });
    }
  };

  // Refetch after successful tx
  if (isSuccess) {
    allowedChecks.refetch();
  }

  if (!collateralList) {
    return null;
  }

  return (
    <div className="rounded-xl border border-zinc-200 dark:border-zinc-800">
      <div className="border-b border-zinc-200 px-5 py-3 dark:border-zinc-800">
        <h2 className="font-semibold text-black dark:text-white">
          Collateral
        </h2>
      </div>
      <div className="flex flex-col gap-2 p-5">
        {collateralList.map((token, i) => {
          const isEnabled = allowedChecks.data?.[i]?.result === true;
          const name = tokenNames.data?.[i]?.result ?? "Unknown";
          const symbol = tokenSymbols.data?.[i]?.result ?? "...";
          const canDisable = enabledCount > 1;

          return (
            <div
              key={token}
              className="flex items-center gap-4 rounded-lg border border-zinc-100 p-3 dark:border-zinc-800"
            >
              <div
                className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold ${
                  isEnabled
                    ? "bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300"
                    : "bg-zinc-100 text-zinc-400 dark:bg-zinc-800 dark:text-zinc-500"
                }`}
              >
                {(symbol as string).slice(0, 3)}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium text-black dark:text-white">
                  {symbol as string}
                </p>
                <p className="text-xs text-zinc-400 truncate">
                  {name as string} &middot;{" "}
                  <span className="font-mono">{truncateAddress(token)}</span>
                </p>
              </div>
              <span
                className={`text-xs font-medium ${
                  isEnabled
                    ? "text-green-600 dark:text-green-400"
                    : "text-zinc-400"
                }`}
              >
                {isEnabled ? "Enabled" : "Disabled"}
              </span>
              {isOwner && (
                <button
                  onClick={() => handleToggle(token, !!isEnabled)}
                  disabled={
                    isPending ||
                    isConfirming ||
                    (isEnabled && !canDisable)
                  }
                  className={`rounded-lg px-3 py-1.5 text-xs font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed ${
                    isEnabled
                      ? "border border-red-200 text-red-600 hover:bg-red-50 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950"
                      : "border border-green-200 text-green-600 hover:bg-green-50 dark:border-green-800 dark:text-green-400 dark:hover:bg-green-950"
                  }`}
                  title={
                    isEnabled && !canDisable
                      ? "At least one collateral must remain enabled"
                      : undefined
                  }
                >
                  {isPending || isConfirming
                    ? "..."
                    : isEnabled
                      ? "Disable"
                      : "Enable"}
                </button>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
