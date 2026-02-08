"use client";

import { useEffect } from "react";
import { useWizard } from "./WizardContext";
import { useReadContract, useReadContracts } from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import {
  getContractAddress,
  ARC_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
  ARBITRUM_USDC,
  WA_ARB_USDC_VAULT,
} from "@/contracts/addresses";
import { type Address, formatUnits, erc20Abi } from "viem";
import { Card, CardContent } from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Alert, AlertDescription } from "@/components/ui/alert";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

function YieldPegCollateral() {
  const { setState } = useWizard();

  // Auto-select USDC as underlying for the newInstance tokens array
  useEffect(() => {
    setState({ selectedCollateral: [ARBITRUM_USDC] });
  }, [setState]);

  return (
    <div className="flex flex-col gap-6">
      <Alert>
        <AlertDescription>
          Yield Peg instances use an ERC-4626 vault as collateral. Deposited
          assets earn yield while backing your stablecoin. Deploys on Arbitrum.
        </AlertDescription>
      </Alert>

      <Card className="border-primary bg-primary/5">
        <CardContent className="flex items-center gap-4 p-4">
          <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary">
            waU
          </div>
          <div className="flex-1 min-w-0">
            <div className="flex items-baseline gap-2">
              <p className="font-semibold">waArbUSDCn</p>
              <p className="text-sm text-muted-foreground truncate">
                Aave Arbitrum USDC Vault
              </p>
            </div>
            <div className="flex gap-3 mt-1 text-xs text-muted-foreground/60">
              <span>ERC-4626</span>
              <span>Underlying: USDC</span>
              <span className="font-mono">
                {truncateAddress(WA_ARB_USDC_VAULT)}
              </span>
            </div>
          </div>
        </CardContent>
      </Card>

      <p className="text-sm text-muted-foreground">
        Your stablecoin will be backed by{" "}
        <span className="font-medium text-foreground">
          Aave waArbUSDCn vault shares
        </span>
        . Depositors can supply any token from any chain — it will be
        automatically swapped into vault shares via LiFi.
      </p>
    </div>
  );
}

export function StepCollateral() {
  const { state, setState } = useWizard();

  if (state.pegStyle === "yield") {
    return <YieldPegCollateral />;
  }

  const chainId = ARC_CHAIN_ID;
  const addresses = getContractAddress(chainId);
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
    chainId,
    query: { enabled: !!contractAddress },
  });

  // Fetch collateral config (debt cap, decimals, etc.) for each token
  const collateralConfigs = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "getGlobalCollateral" as const,
      args: [token] as const,
      chainId,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  // Fetch ERC20 name() for each token
  const tokenNames = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "name" as const,
      chainId,
    })),
    query: { enabled: !!collateralList && collateralList.length > 0 },
  });

  // Fetch ERC20 symbol() for each token
  const tokenSymbols = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: token,
      abi: erc20Abi,
      functionName: "symbol" as const,
      chainId,
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
    return (
      <p className="text-muted-foreground">Loading available collateral...</p>
    );
  }

  if (listError || !collateralList) {
    return (
      <Alert>
        <AlertDescription>
          Could not load collateral from the protocol. Make sure the contract is
          deployed and your wallet is on the correct network.
        </AlertDescription>
      </Alert>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <Alert>
        <AlertDescription>
          Collateral backs your stablecoin 1:1. Every coin minted must have an
          equal value of collateral deposited. Only stablecoins are available as
          collateral for this peg type.
        </AlertDescription>
      </Alert>

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
            <Card
              key={token}
              className={`cursor-pointer transition-colors ${
                isSelected
                  ? "border-primary bg-primary/5"
                  : "hover:border-muted-foreground/30"
              }`}
              onClick={() => toggleCollateral(token)}
            >
              <CardContent className="flex items-center gap-4 p-4">
                <div
                  className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-bold ${
                    isSelected
                      ? "bg-primary/10 text-primary"
                      : "bg-muted text-muted-foreground"
                  }`}
                >
                  {(symbol || "?").slice(0, 3)}
                </div>

                <div className="flex-1 min-w-0">
                  <div className="flex items-baseline gap-2">
                    <p className="font-semibold">{displaySymbol}</p>
                    <p className="text-sm text-muted-foreground truncate">
                      {displayName}
                    </p>
                  </div>
                  <div className="flex gap-3 mt-1 text-xs text-muted-foreground/60">
                    <span>{decimals} decimals</span>
                    {config && (
                      <span>
                        Debt cap: {formatUnits(config.debtCap, 18)}
                      </span>
                    )}
                    <span className="font-mono">{truncateAddress(token)}</span>
                  </div>
                </div>

                <Checkbox
                  checked={isSelected}
                  onCheckedChange={() => toggleCollateral(token)}
                  onClick={(e) => e.stopPropagation()}
                />
              </CardContent>
            </Card>
          );
        })}
      </div>

      {state.selectedCollateral.length > 0 && (
        <p className="text-sm text-muted-foreground">
          Your coin will be backed by:{" "}
          <span className="font-medium text-foreground">
            {state.selectedCollateral
              .map((t) => {
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
