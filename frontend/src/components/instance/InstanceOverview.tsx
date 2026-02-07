"use client";

import { useState } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import { useReadContract, useReadContracts } from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { erc20Abi, formatUnits, type Address } from "viem";

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
    <div className="rounded-xl border border-zinc-200 dark:border-zinc-800">
      <div className="flex items-center justify-between border-b border-zinc-200 px-5 py-3 dark:border-zinc-800">
        <h2 className="font-semibold text-black dark:text-white">Overview</h2>
        {isOwner && (
          <span className="rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-700 dark:bg-blue-900 dark:text-blue-300">
            Owner
          </span>
        )}
      </div>
      <div className="divide-y divide-zinc-100 px-5 dark:divide-zinc-800">
        <Row label="Coin Name" value={coinName ?? "Loading..."} />
        <Row label="Symbol" value={coinSymbol ?? "..."} />
        <CopyableRow
          label="Coin Address"
          displayValue={coinAddress ? truncateAddress(coinAddress) : "..."}
          copyValue={coinAddress}
        />
        <Row label="App ID" value={`#${appId.toString()}`} />
        <Row
          label="Owner"
          value={owner ? truncateAddress(owner) : "..."}
          mono
        />
        <Row
          label="Total Supply"
          value={
            totalSupply !== undefined
              ? `${formatUnits(totalSupply, 18)} ${coinSymbol ?? ""}`
              : "..."
          }
        />
        <Row
          label="Your Vault Balance"
          value={
            vaultBalance !== undefined
              ? `${vaultBalance.toString()} value units`
              : "..."
          }
        />
      </div>
    </div>
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
      <span className="text-sm text-zinc-400">{label}</span>
      <span
        className={`text-sm text-black dark:text-white ${mono ? "font-mono" : ""}`}
      >
        {value}
      </span>
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
      <span className="text-sm text-zinc-400">{label}</span>
      <button
        onClick={handleCopy}
        disabled={!copyValue}
        className="flex items-center gap-1.5 font-mono text-sm text-black transition-colors hover:text-blue-600 dark:text-white dark:hover:text-blue-400 disabled:pointer-events-none"
      >
        {displayValue}
        {copyValue && (
          <span className="text-xs text-zinc-400">
            {copied ? "Copied!" : "Copy"}
          </span>
        )}
      </button>
    </div>
  );
}
