"use client";

import { useState } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import { useReadContract, useReadContracts } from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
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

const ARC_CHAIN_ID = 5042002;

export function InstanceOverview({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress },
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
            chainId: ARC_CHAIN_ID,
          },
          {
            address: coinAddress,
            abi: erc20Abi,
            functionName: "symbol" as const,
            chainId: ARC_CHAIN_ID,
          },
          {
            address: coinAddress,
            abi: erc20Abi,
            functionName: "totalSupply" as const,
            chainId: ARC_CHAIN_ID,
          },
        ]
      : [],
    query: { enabled: !!coinAddress },
  });

  const { data: vaultBalance } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
  });

  const coinName = coinReads.data?.[0]?.result as string | undefined;
  const coinSymbol = coinReads.data?.[1]?.result as string | undefined;
  const totalSupply = coinReads.data?.[2]?.result as bigint | undefined;

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>Overview</CardTitle>
        {isOwner && <Badge>Owner</Badge>}
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
        <Row
          label="Your Vault Balance"
          value={
            vaultBalance !== undefined
              ? `${vaultBalance.toString()} value units`
              : "..."
          }
        />
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
