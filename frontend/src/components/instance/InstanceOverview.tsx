"use client";

import { useState } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import { useReadContract, useReadContracts } from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import { getContractAddress } from "@/contracts/addresses";
import { erc20Abi, formatUnits, type Address } from "viem";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

type PegType = "hard" | "medium";

export function InstanceOverview({
  appId,
  pegType = "hard",
  chainId = 5042002,
}: {
  appId: bigint;
  pegType?: PegType;
  chainId?: number;
}) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(chainId);
  const contractAddress =
    pegType === "medium" ? addresses?.mediumPeg : addresses?.hardPeg;
  const abi = pegType === "medium" ? mediumPegAbi : hardPegAbi;

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi,
    functionName: "getAppConfig",
    args: [appId],
    chainId,
    query: { enabled: !!contractAddress, staleTime: 30_000 },
  });

  const coinAddress = appConfig?.coin as Address | undefined;
  const owner = appConfig?.owner as Address | undefined;
  const isOwner =
    !!address && !!owner && address.toLowerCase() === owner.toLowerCase();

  const coinReads = useReadContracts({
    contracts: coinAddress
      ? [
          {
            address: coinAddress,
            abi: erc20Abi,
            functionName: "name" as const,
            chainId,
          },
          {
            address: coinAddress,
            abi: erc20Abi,
            functionName: "symbol" as const,
            chainId,
          },
          {
            address: coinAddress,
            abi: erc20Abi,
            functionName: "totalSupply" as const,
            chainId,
          },
        ]
      : [],
    query: { enabled: !!coinAddress, staleTime: 30_000 },
  });

  // HardPeg: vault balance (single value)
  const { data: vaultBalance } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId,
    query: { enabled: pegType === "hard" && !!contractAddress && !!address, staleTime: 30_000 },
  });

  // MediumPeg: position (principal + shares)
  const { data: position } = useReadContract({
    address: contractAddress,
    abi: mediumPegAbi,
    functionName: "getPosition",
    args: [appId, address as Address],
    chainId,
    query: { enabled: pegType === "medium" && !!contractAddress && !!address, staleTime: 30_000 },
  });

  const coinName = coinReads.data?.[0]?.result as string | undefined;
  const coinSymbol = coinReads.data?.[1]?.result as string | undefined;
  const totalSupply = coinReads.data?.[2]?.result as bigint | undefined;

  const pegLabel = pegType === "hard" ? "Hard Peg" : "Yield Peg";
  const chainLabel = chainId === 5042002 ? "Arc Testnet" : "Arbitrum";

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>Overview</CardTitle>
        <div className="flex items-center gap-2">
          <Badge variant="outline">{chainLabel}</Badge>
          <Badge variant={pegType === "hard" ? "default" : "secondary"}>
            {pegLabel}
          </Badge>
          {isOwner && <Badge>Owner</Badge>}
        </div>
      </CardHeader>
      <CardContent className="px-5 py-0 pb-1">
        <Row label="Coin Name" value={coinName ?? "Loading..."} />
        <Separator />
        <Row label="Symbol" value={coinSymbol ?? "..."} />
        <Separator />
        <CopyableRow
          label="Coin Address"
          displayValue={coinAddress ? truncateAddress(coinAddress) : "..."}
          copyValue={coinAddress}
        />
        <Separator />
        <Row label="App ID" value={`#${appId.toString()}`} />
        <Separator />
        <Row
          label="Owner"
          value={owner ? truncateAddress(owner) : "..."}
          mono
        />
        <Separator />
        <Row
          label="Total Supply"
          value={
            totalSupply !== undefined
              ? `${formatUnits(totalSupply, 18)} ${coinSymbol ?? ""}`
              : "..."
          }
        />
        <Separator />
        {pegType === "hard" ? (
          <Row
            label="Your Vault Balance"
            value={
              vaultBalance !== undefined
                ? `${vaultBalance.toString()} value units`
                : "..."
            }
          />
        ) : (
          <>
            <Row
              label="Your Principal"
              value={
                position
                  ? `${formatUnits((position as [bigint, bigint])[0], 6)} USDC`
                  : "..."
              }
            />
            <Separator />
            <Row
              label="Your Shares"
              value={
                position
                  ? `${formatUnits((position as [bigint, bigint])[1], 6)}`
                  : "..."
              }
            />
          </>
        )}
      </CardContent>
    </Card>
  );
}

function Row({
  label,
  value,
  mono,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="flex justify-between py-3">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className={`text-sm ${mono ? "font-mono" : ""}`}>{value}</span>
    </div>
  );
}

function CopyableRow({
  label,
  displayValue,
  copyValue,
}: {
  label: string;
  displayValue: string;
  copyValue?: string;
}) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    if (!copyValue) return;
    navigator.clipboard.writeText(copyValue);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="flex justify-between py-3">
      <span className="text-sm text-muted-foreground">{label}</span>
      <TooltipProvider>
        <Tooltip>
          <TooltipTrigger asChild>
            <button
              onClick={handleCopy}
              disabled={!copyValue}
              className="flex items-center gap-1.5 font-mono text-sm transition-colors hover:text-primary disabled:pointer-events-none"
            >
              {displayValue}
              {copyValue && (
                <span className="text-xs text-muted-foreground">
                  {copied ? "Copied!" : "Copy"}
                </span>
              )}
            </button>
          </TooltipTrigger>
          <TooltipContent>
            <p>{copyValue}</p>
          </TooltipContent>
        </Tooltip>
      </TooltipProvider>
    </div>
  );
}
