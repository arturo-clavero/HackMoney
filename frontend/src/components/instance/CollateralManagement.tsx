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
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

const ARC_CHAIN_ID = 5042002;

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function CollateralManagement({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  // Read app config to determine owner
  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId],
    chainId: ARC_CHAIN_ID,
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
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress },
  });

  // Check which are allowed for this app
  const allowedChecks = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "isAppCollateralAllowed" as const,
      args: [appId, token] as const,
      chainId: ARC_CHAIN_ID,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  // Fetch ERC20 name/symbol per token
  const tokenNames = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "name" as const,
      chainId: ARC_CHAIN_ID,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  const tokenSymbols = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "symbol" as const,
      chainId: ARC_CHAIN_ID,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  const { writeContract, isPending, data: txHash } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

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
    <Card>
      <CardHeader>
        <CardTitle>Collateral</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {collateralList.map((token, i) => {
          const isEnabled = allowedChecks.data?.[i]?.result === true;
          const name = tokenNames.data?.[i]?.result ?? "Unknown";
          const symbol = tokenSymbols.data?.[i]?.result ?? "...";
          const canDisable = enabledCount > 1;

          return (
            <div
              key={token}
              className="flex items-center gap-4 rounded-lg border border-border p-3"
            >
              <div
                className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold ${
                  isEnabled
                    ? "bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300"
                    : "bg-muted text-muted-foreground"
                }`}
              >
                {(symbol as string).slice(0, 3)}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-medium">{symbol as string}</p>
                <p className="text-xs text-muted-foreground truncate">
                  {name as string} &middot;{" "}
                  <span className="font-mono">{truncateAddress(token)}</span>
                </p>
              </div>
              <Badge variant={isEnabled ? "default" : "secondary"}>
                {isEnabled ? "Enabled" : "Disabled"}
              </Badge>
              {isOwner && (
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleToggle(token, !!isEnabled)}
                  disabled={
                    isPending ||
                    isConfirming ||
                    (isEnabled && !canDisable)
                  }
                  className={
                    isEnabled
                      ? "border-red-200 text-red-600 hover:bg-red-50 dark:border-red-800 dark:text-red-400 dark:hover:bg-red-950"
                      : "border-green-200 text-green-600 hover:bg-green-50 dark:border-green-800 dark:text-green-400 dark:hover:bg-green-950"
                  }
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
                </Button>
              )}
            </div>
          );
        })}
      </CardContent>
    </Card>
  );
}
