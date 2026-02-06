"use client";

import { useWizard } from "./WizardContext";
import { useReadContract, useReadContracts } from "wagmi";
import { useAppKitAccount } from "@reown/appkit/react";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { type Address, formatUnits, erc20Abi } from "viem";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function StepCollateral() {
  const { state, setState } = useWizard();
  const { caipAddress } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;

  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  // Fetch registered collateral addresses from protocol
  const {
    data: collateralList,
    isLoading: listLoading,
    isError: listError,
  } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getGlobalCollateralList",
    query: { enabled: !!contractAddress },
  });

  // Fetch collateral config (debt cap, decimals, etc.) for each token
  const collateralConfigs = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "getGlobalCollateral" as const,
      args: [token] as const,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  // Fetch ERC20 name() for each token
  const tokenNames = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "name" as const,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  // Fetch ERC20 symbol() for each token
  const tokenSymbols = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "symbol" as const,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  const toggleCollateral = (token: Address) => {
    const current = state.selectedCollateral;
    const updated = current.includes(token)
      ? current.filter((t) => t !== token)
      : [...current, token];
    setState({ selectedCollateral: updated });
  };

  if (listLoading) {
    return <p className="text-zinc-500">Loading available collateral...</p>;
  }

  if (listError || !collateralList) {
    return (
      <div className="rounded-lg bg-yellow-50 p-4 text-sm text-yellow-800 dark:bg-yellow-950 dark:text-yellow-200">
        Could not load collateral from the protocol. Make sure the contract is
        deployed and your wallet is on the correct network.
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="rounded-lg bg-blue-50 p-4 text-sm text-blue-800 dark:bg-blue-950 dark:text-blue-200">
        {state.pegStyle === "hard"
          ? "Collateral backs your stablecoin 1:1. Every coin minted must have an equal value of collateral deposited. Only stablecoins are available as collateral for this peg type."
          : state.pegStyle === "yield"
            ? "Collateral is yield-bearing. Your backing assets earn yield while sitting behind your stablecoin."
            : "Collateral is volatile. Overcollateralization is required and positions carry liquidation risk."}
      </div>

      <div className="flex flex-col gap-3">
        {collateralList.map((token, i) => {
          const config = collateralConfigs.data?.[i]?.result;
          const name = tokenNames.data?.[i]?.result;
          const symbol = tokenSymbols.data?.[i]?.result;
          const isSelected = state.selectedCollateral.includes(token);
          const displayName = name || "Unknown Token";
          const displaySymbol = symbol || truncateAddress(token);
          const decimals = config ? Number(config.decimals) : 18;

          return (
            <button
              key={token}
              onClick={() => toggleCollateral(token)}
              className={`flex items-center gap-4 rounded-xl border p-4 text-left transition-colors ${
                isSelected
                  ? "border-blue-500 bg-blue-50 dark:bg-blue-950"
                  : "border-zinc-200 hover:border-zinc-300 dark:border-zinc-800 dark:hover:border-zinc-700"
              }`}
            >
              {/* Token icon placeholder */}
              <div
                className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold ${
                  isSelected
                    ? "bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300"
                    : "bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-400"
                }`}
              >
                {(symbol || "?").slice(0, 3)}
              </div>

              {/* Token info */}
              <div className="flex-1 min-w-0">
                <div className="flex items-baseline gap-2">
                  <p className="font-semibold text-black dark:text-white">
                    {displaySymbol}
                  </p>
                  <p className="text-sm text-zinc-500 truncate">
                    {displayName}
                  </p>
                </div>
                <div className="flex gap-3 mt-1 text-xs text-zinc-400">
                  <span>{decimals} decimals</span>
                  {config && (
                    <span>
                      Debt cap: {formatUnits(config.debtCap, 18)}
                    </span>
                  )}
                  <span className="font-mono">{truncateAddress(token)}</span>
                </div>
              </div>

              {/* Checkbox */}
              <div
                className={`h-5 w-5 shrink-0 rounded border-2 flex items-center justify-center ${
                  isSelected
                    ? "border-blue-600 bg-blue-600 text-white"
                    : "border-zinc-300 dark:border-zinc-600"
                }`}
              >
                {isSelected && <span className="text-xs">{"\u2713"}</span>}
              </div>
            </button>
          );
        })}
      </div>

      {state.selectedCollateral.length > 0 && (
        <p className="text-sm text-zinc-500">
          Your coin will be backed by:{" "}
          <span className="font-medium text-black dark:text-white">
            {state.selectedCollateral
              .map((t, i) => {
                const idx = collateralList.indexOf(t);
                return tokenSymbols.data?.[idx]?.result || truncateAddress(t);
              })
              .join(", ")}
          </span>
        </p>
      )}
    </div>
  );
}
