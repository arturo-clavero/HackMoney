"use client";

import Link from "next/link";
import { useAppKit, useAppKitAccount } from "@reown/appkit/react";
import {
  useAccount,
  useWatchContractEvent,
  useReadContracts,
  usePublicClient,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { erc20Abi, type Address } from "viem";
import { useState, useEffect } from "react";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

interface Instance {
  id: bigint;
  coin: Address;
}

function InstancesList() {
  const { caipAddress, address } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  const publicClient = usePublicClient();
  const [instances, setInstances] = useState<Instance[]>([]);
  const [loaded, setLoaded] = useState(false);

  // One-time fetch of historical events (deterministic loading state)
  useEffect(() => {
    if (!contractAddress || !address || !publicClient) return;
    let cancelled = false;

    publicClient
      .getContractEvents({
        address: contractAddress,
        abi: hardPegAbi,
        eventName: "RegisteredApp",
        args: { owner: address as Address },
        fromBlock: BigInt(0),
      })
      .then((logs) => {
        if (cancelled) return;
        const newInstances = logs.map((log) => ({
          id: log.args.id!,
          coin: log.args.coin! as Address,
        }));
        setInstances(newInstances);
        setLoaded(true);
      })
      .catch(() => {
        if (!cancelled) setLoaded(true);
      });

    return () => {
      cancelled = true;
    };
  }, [contractAddress, address, publicClient]);

  // Watch for NEW events while the page is open
  useWatchContractEvent({
    address: contractAddress,
    abi: hardPegAbi,
    eventName: "RegisteredApp",
    args: { owner: address as Address },
    onLogs(logs) {
      const newInstances = logs.map((log) => ({
        id: log.args.id!,
        coin: log.args.coin! as Address,
      }));
      setInstances((prev) => {
        const existingIds = new Set(prev.map((i) => i.id.toString()));
        const unique = newInstances.filter(
          (i) => !existingIds.has(i.id.toString())
        );
        return unique.length > 0 ? [...prev, ...unique] : prev;
      });
    },
    enabled: !!contractAddress && !!address,
  });

  // Read name() and symbol() for each coin
  const coinNames = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "name" as const,
    })),
    query: { enabled: instances.length > 0 },
  });

  const coinSymbols = useReadContracts({
    contracts: instances.map((inst) => ({
      address: inst.coin,
      abi: erc20Abi,
      functionName: "symbol" as const,
    })),
    query: { enabled: instances.length > 0 },
  });

  if (!contractAddress) {
    return (
      <div className="rounded-lg bg-yellow-50 p-4 text-sm text-yellow-800 dark:bg-yellow-950 dark:text-yellow-200">
        Switch to a supported network to see your instances.
      </div>
    );
  }

  if (!loaded) {
    return (
      <div className="flex items-center justify-center gap-3 py-12">
        <div className="h-5 w-5 animate-spin rounded-full border-2 border-zinc-300 border-t-blue-600" />
        <p className="text-sm text-zinc-500">Loading your stablecoins...</p>
      </div>
    );
  }

  if (instances.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2 rounded-xl border border-dashed border-zinc-300 p-8 dark:border-zinc-700">
        <p className="text-zinc-500">No stablecoin instances yet.</p>
        <p className="text-sm text-zinc-400">Use the button above to create one.</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      {instances.map((inst, i) => {
        const name = coinNames.data?.[i]?.result ?? "Loading...";
        const symbol = coinSymbols.data?.[i]?.result ?? "...";

        return (
          <Link
            key={inst.id.toString()}
            href={`/instance/${inst.id.toString()}`}
            className="flex items-center gap-4 rounded-xl border border-zinc-200 p-4 transition-colors hover:border-blue-400 hover:bg-zinc-50 dark:border-zinc-800 dark:hover:border-blue-600 dark:hover:bg-zinc-900"
          >
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-blue-100 text-sm font-bold text-blue-700 dark:bg-blue-900 dark:text-blue-300">
              {symbol.slice(0, 3)}
            </div>
            <div className="flex-1 min-w-0">
              <div className="flex items-baseline gap-2">
                <p className="font-semibold text-black dark:text-white">
                  {symbol}
                </p>
                <p className="text-sm text-zinc-500 truncate">{name}</p>
              </div>
              <div className="flex gap-3 mt-1 text-xs text-zinc-400">
                <span>App #{inst.id.toString()}</span>
                <span className="font-mono">{truncateAddress(inst.coin)}</span>
              </div>
            </div>
          </Link>
        );
      })}
    </div>
  );
}

export default function Home() {
  const { open } = useAppKit();
  const { isConnected } = useAppKitAccount();
  const { status } = useAccount();

  // Wallet is restoring a previous session — render nothing to avoid layout flash
  if (status === "reconnecting" || status === "connecting") {
    return null;
  }

  if (!isConnected) {
    return (
      <div className="flex min-h-[calc(100vh-57px)] items-center justify-center">
        <div className="flex flex-col items-center gap-6">
          <h1 className="text-4xl font-bold text-black dark:text-white">
            HackMoney
          </h1>
          <p className="text-zinc-500 text-center max-w-md">
            Create and manage your own stablecoin instances backed by
            protocol-approved collateral.
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
    <div className="mx-auto max-w-2xl px-6 py-12">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-2xl font-bold text-black dark:text-white">
          My Stablecoins
        </h1>
        <Link
          href="/create"
          className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700"
        >
          + Create New
        </Link>
      </div>
      <InstancesList />
    </div>
  );
}
