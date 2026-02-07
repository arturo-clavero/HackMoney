"use client";

import { useState, useEffect, useCallback, useRef, useMemo } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useWriteContract,
  useSwitchChain,
  useConfig,
} from "wagmi";
import { waitForTransactionReceipt as waitForTxReceipt } from "@wagmi/core";
import {
  erc20Abi,
  formatUnits,
  parseUnits,
  type Address,
} from "viem";
import type { TokenAmount } from "@lifi/sdk";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import {
  getContractAddress,
  USDC_ADDRESSES,
  ARC_CHAIN_ID,
  ARC_USDC,
  isCircleBridgeChain,
  getCircleBridgeConfig,
} from "@/contracts/addresses";
import { useLifiTokens, useLifiQuote, useLifiExecution } from "@/hooks/useLifi";
import { useBridgeToArc } from "@/hooks/useBridgeToArc";
import { TokenSelectorModal } from "./TokenSelectorModal";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { Card, CardContent } from "@/components/ui/card";
import { motion } from "@/components/motion";

// ─── Route Detection ─────────────────────────────────────────────────────────

type DepositRoute = "direct" | "bridge" | "full";

function detectRoute(tokenAddress: string, chainId: number): DepositRoute {
  if (
    chainId === ARC_CHAIN_ID &&
    tokenAddress.toLowerCase() === ARC_USDC.toLowerCase()
  ) {
    return "direct";
  }
  const config = getCircleBridgeConfig(chainId);
  if (config && tokenAddress.toLowerCase() === config.usdc.toLowerCase()) {
    return "bridge";
  }
  return "full";
}

function getRouteSteps(route: DepositRoute): string[] {
  switch (route) {
    case "direct":
      return ["Deposit"];
    case "bridge":
      return ["Bridge to Arc", "Deposit"];
    case "full":
      return ["Swap to USDC", "Bridge to Arc", "Deposit"];
  }
}

function getRouteBadge(route: DepositRoute): { label: string; variant: "default" | "secondary" | "outline" } {
  switch (route) {
    case "direct":
      return { label: "Direct Deposit", variant: "default" };
    case "bridge":
      return { label: "Bridge + Deposit", variant: "secondary" };
    case "full":
      return { label: "Swap + Bridge + Deposit", variant: "outline" };
  }
}

// ─── Step States ─────────────────────────────────────────────────────────────

type StepStatus = "pending" | "active" | "done" | "error";

interface StepState {
  label: string;
  status: StepStatus;
  error?: string;
}

// ─── Step Progress Tracker ───────────────────────────────────────────────────

function StepTracker({ steps }: { steps: StepState[] }) {
  return (
    <div className="mb-4 flex items-center gap-2">
      {steps.map((step, idx) => (
        <div key={step.label} className="flex items-center gap-2">
          <div className="flex items-center gap-1.5">
            <motion.div
              initial={false}
              animate={{
                scale: step.status === "active" ? 1.1 : 1,
                backgroundColor:
                  step.status === "done"
                    ? "var(--color-green-600, #16a34a)"
                    : step.status === "active"
                      ? "var(--color-primary, #2563eb)"
                      : step.status === "error"
                        ? "var(--color-destructive, #dc2626)"
                        : "var(--color-muted, #e4e4e7)",
              }}
              transition={{ type: "spring", stiffness: 300, damping: 20 }}
              className="flex h-6 w-6 items-center justify-center rounded-full text-xs font-medium text-primary-foreground"
            >
              {step.status === "done" ? (
                <motion.span
                  initial={{ scale: 0 }}
                  animate={{ scale: 1 }}
                  transition={{ type: "spring", stiffness: 400, damping: 15 }}
                >
                  <svg className="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                  </svg>
                </motion.span>
              ) : step.status === "error" ? (
                <span className="text-white">!</span>
              ) : (
                <span className={step.status === "active" ? "text-white" : "text-muted-foreground"}>
                  {idx + 1}
                </span>
              )}
            </motion.div>
            <span
              className={`text-xs font-medium ${
                step.status === "done"
                  ? "text-green-600 dark:text-green-400"
                  : step.status === "active"
                    ? "text-primary"
                    : step.status === "error"
                      ? "text-destructive"
                      : "text-muted-foreground"
              }`}
            >
              {step.label}
            </span>
          </div>
          {idx < steps.length - 1 && (
            <div
              className={`h-px w-6 ${
                step.status === "done"
                  ? "bg-green-600"
                  : "bg-border"
              }`}
            />
          )}
        </div>
      ))}
    </div>
  );
}

// ─── Main Component ──────────────────────────────────────────────────────────

export function DepositFlow({ appId }: { appId: bigint }) {
  const wagmiConfig = useConfig();
  const { caipAddress, address } = useAppKitAccount();
  const walletChainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const contractAddresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = contractAddresses?.hardPeg;
  const { switchChainAsync } = useSwitchChain();

  // ─── Token & amount state ──────────────────────────────────────────────
  const [sourceModalOpen, setSourceModalOpen] = useState(false);
  const [sourceToken, setSourceToken] = useState<TokenAmount | null>(null);
  const [sourceChainId, setSourceChainId] = useState<number | null>(null);
  const [amount, setAmount] = useState("");
  const [slippage, setSlippage] = useState("0.5");
  const [showSlippage, setShowSlippage] = useState(false);

  // ─── Execution state ───────────────────────────────────────────────────
  const [executing, setExecuting] = useState(false);
  const [steps, setSteps] = useState<StepState[]>([]);
  const [currentStepIdx, setCurrentStepIdx] = useState(-1);
  const [flowDone, setFlowDone] = useState(false);
  const [flowError, setFlowError] = useState<string | null>(null);

  // ─── Deposit step refs (to avoid duplicate deposit fires) ──────────────
  const depositFiredRef = useRef(false);

  // ─── LI.FI hooks ──────────────────────────────────────────────────────
  const {
    chains,
    tokensByChain,
    isLoading: tokensLoading,
    loadingBalancesChainId,
    load: loadTokens,
    loadBalancesForChain,
    loadAllBalances,
  } = useLifiTokens(address);

  const {
    quote,
    isLoading: quoteLoading,
    error: quoteError,
    fetchQuote,
    clearQuote,
  } = useLifiQuote();

  const {
    execute: executeSwap,
    resetStatus: resetSwapStatus,
    setStatus: setSwapStatus,
  } = useLifiExecution();

  // ─── Circle bridge hook ────────────────────────────────────────────────
  const {
    bridge,
    reset: resetBridge,
  } = useBridgeToArc();

  // ─── Contract write hooks (approve + deposit on Arc) ───────────────────
  const {
    writeContractAsync: writeApproveAsync,
  } = useWriteContract();

  const {
    writeContractAsync: writeDepositAsync,
  } = useWriteContract();

  // ─── USDC balance on Arc ───────────────────────────────────────────────
  const { data: arcUsdcBalance } = useReadContract({
    address: ARC_USDC,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!address },
  });

  // ─── USDC balance on Arb Sepolia ──────────────────────────────────────
  const ARB_SEPOLIA_CHAIN_ID = 421614;
  const ARB_SEPOLIA_USDC = USDC_ADDRESSES[ARB_SEPOLIA_CHAIN_ID];
  const { data: arbSepoliaUsdcBalance } = useReadContract({
    address: ARB_SEPOLIA_USDC,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId: ARB_SEPOLIA_CHAIN_ID,
    query: { enabled: !!address },
  });

  // ─── Vault balance ────────────────────────────────────────────────────
  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
  });

  // ─── Load tokens on mount ─────────────────────────────────────────────
  useEffect(() => {
    loadTokens(walletChainId);
  }, [loadTokens, walletChainId]);

  // ─── Inject testnet chains into the LI.FI lists ───────────────────────
  const allChains = useMemo(() => {
    const testnetChains = [
      { id: ARC_CHAIN_ID, name: "Arc Testnet", logoURI: "" },
      { id: ARB_SEPOLIA_CHAIN_ID, name: "Arbitrum Sepolia", logoURI: "" },
    ];
    // Prepend testnet chains, skip if LI.FI somehow already includes them
    const lifiIds = new Set(chains.map((c) => c.id));
    const extras = testnetChains.filter((c) => !lifiIds.has(c.id));
    return [...extras, ...chains] as typeof chains;
  }, [chains]);

  const allTokensByChain = useMemo(() => {
    const merged = { ...tokensByChain };
    // Arc testnet USDC
    if (!merged[ARC_CHAIN_ID]) {
      merged[ARC_CHAIN_ID] = [
        {
          address: ARC_USDC,
          chainId: ARC_CHAIN_ID,
          symbol: "USDC",
          decimals: 6,
          name: "USD Coin",
          priceUSD: "1",
          logoURI: "",
          amount: arcUsdcBalance ?? BigInt(0),
        } as unknown as TokenAmount,
      ];
    }
    // Arb Sepolia USDC
    if (!merged[ARB_SEPOLIA_CHAIN_ID]) {
      merged[ARB_SEPOLIA_CHAIN_ID] = [
        {
          address: ARB_SEPOLIA_USDC,
          chainId: ARB_SEPOLIA_CHAIN_ID,
          symbol: "USDC",
          decimals: 6,
          name: "USD Coin",
          priceUSD: "1",
          logoURI: "",
          amount: arbSepoliaUsdcBalance ?? BigInt(0),
        } as unknown as TokenAmount,
      ];
    }
    return merged;
  }, [tokensByChain, arcUsdcBalance, arbSepoliaUsdcBalance]);

  // ─── Route detection ──────────────────────────────────────────────────
  const route: DepositRoute | null =
    sourceToken && sourceChainId
      ? detectRoute(sourceToken.address, sourceChainId)
      : null;

  const routeBadge = route ? getRouteBadge(route) : null;

  // ─── Token selection handler ──────────────────────────────────────────
  const handleSourceSelect = useCallback(
    (token: TokenAmount, tokenChainId: number) => {
      setSourceToken(token);
      setSourceChainId(tokenChainId);
      setAmount("");
      clearQuote();
      resetSwapStatus();
      resetBridge();
      setExecuting(false);
      setSteps([]);
      setCurrentStepIdx(-1);
      setFlowDone(false);
      setFlowError(null);
    },
    [clearQuote, resetSwapStatus, resetBridge]
  );

  // ─── Auto-quote for "full" route (LI.FI) ─────────────────────────────
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (route !== "full" || !sourceToken || !sourceChainId || !address || !amount) {
      if (route !== "full") clearQuote();
      return;
    }

    let rawAmount: string;
    try {
      rawAmount = parseUnits(amount, sourceToken.decimals).toString();
      if (rawAmount === "0") return;
    } catch {
      return;
    }

    // LI.FI only supports mainnet — quote swap to USDC on Arbitrum mainnet
    const ARB_MAINNET_CHAIN_ID = 42161;
    const ARB_MAINNET_USDC = USDC_ADDRESSES[ARB_MAINNET_CHAIN_ID];

    debounceRef.current = setTimeout(() => {
      fetchQuote({
        fromChain: sourceChainId,
        toChain: ARB_MAINNET_CHAIN_ID,
        fromToken: sourceToken.address,
        toToken: ARB_MAINNET_USDC,
        fromAmount: rawAmount,
        fromAddress: address,
      });
    }, 500);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [route, sourceToken, sourceChainId, address, amount, fetchQuote, clearQuote]);

  // ─── Helper: wait for tx receipt (uses wagmi's configured transports) ──
  const waitForTx = useCallback(
    async (hash: `0x${string}`) => {
      return waitForTxReceipt(wagmiConfig, { hash, chainId: ARC_CHAIN_ID });
    },
    [wagmiConfig]
  );

  // ─── Execution engine ─────────────────────────────────────────────────

  const updateStep = useCallback(
    (idx: number, update: Partial<StepState>) => {
      setSteps((prev) => {
        const next = [...prev];
        next[idx] = { ...next[idx], ...update };
        return next;
      });
    },
    []
  );

  const executeFromStep = useCallback(
    async (startIdx: number, routeType: DepositRoute, stepLabels: string[]) => {
      setExecuting(true);
      setFlowError(null);

      for (let i = startIdx; i < stepLabels.length; i++) {
        setCurrentStepIdx(i);
        updateStep(i, { status: "active", error: undefined });

        try {
          const stepLabel = stepLabels[i];

          if (stepLabel === "Swap to USDC") {
            // ── LI.FI Swap Step ──
            if (!quote) throw new Error("No quote available");
            await executeSwap(quote.route);
            setSwapStatus("done");
          } else if (stepLabel === "Bridge to Arc") {
            // ── Circle Bridge Step ──
            const bridgeChainId =
              routeType === "bridge" ? sourceChainId! : 421614; // After swap, USDC is on Arb Sepolia
            const config = getCircleBridgeConfig(bridgeChainId);
            if (!config) throw new Error("Bridge chain config not found");

            // Switch to bridge source chain
            if (walletChainId !== bridgeChainId) {
              await switchChainAsync({ chainId: bridgeChainId });
            }

            // Determine bridge amount
            let bridgeAmount: string;
            if (routeType === "full" && quote) {
              // After LI.FI swap, we have the output amount in USDC (6 decimals)
              bridgeAmount = formatUnits(BigInt(quote.toAmount), 6);
            } else {
              bridgeAmount = amount;
            }

            // Execute bridge and wait for completion
            await new Promise<void>((resolve, reject) => {
              bridge(bridgeAmount, config.bridgeChainName)
                .then(() => {
                  const check = setInterval(() => {
                    clearInterval(check);
                    resolve();
                  }, 100);
                })
                .catch(reject);
            });
          } else if (stepLabel === "Deposit") {
            // ── Approve + Deposit Step ──
            if (!contractAddress) throw new Error("Contract address not found");

            // Switch to Arc
            if (walletChainId !== ARC_CHAIN_ID) {
              await switchChainAsync({ chainId: ARC_CHAIN_ID });
            }

            // Determine deposit amount
            let depositRaw: bigint;
            if (routeType === "direct") {
              depositRaw = parseUnits(amount, 6);
            } else if (routeType === "bridge") {
              depositRaw = parseUnits(amount, 6);
            } else {
              // Full route: use LI.FI quote output (already bridged 1:1 via Circle)
              depositRaw = quote ? BigInt(quote.toAmount) : parseUnits(amount, 6);
            }

            // Approve
            const approveTxHash = await writeApproveAsync({
              address: ARC_USDC,
              abi: erc20Abi,
              functionName: "approve",
              args: [contractAddress, depositRaw],
              chainId: ARC_CHAIN_ID,
            });

            await waitForTx(approveTxHash);

            // Deposit
            const depositTxHash = await writeDepositAsync({
              address: contractAddress,
              abi: hardPegAbi,
              functionName: "deposit",
              args: [appId, ARC_USDC, depositRaw],
              chainId: ARC_CHAIN_ID,
            });

            await waitForTx(depositTxHash);
            refetchVault();
          }

          updateStep(i, { status: "done" });
        } catch (err) {
          const errorMsg = err instanceof Error ? err.message : "Step failed";
          updateStep(i, { status: "error", error: errorMsg });
          setFlowError(errorMsg);
          setExecuting(false);
          return;
        }
      }

      setFlowDone(true);
      setExecuting(false);
    },
    [
      quote,
      sourceChainId,
      amount,
      walletChainId,
      contractAddress,
      appId,
      executeSwap,
      setSwapStatus,
      bridge,
      switchChainAsync,
      writeApproveAsync,
      writeDepositAsync,
      waitForTx,
      refetchVault,
      updateStep,
    ]
  );

  // ─── Start execution ──────────────────────────────────────────────────
  const handleDeposit = useCallback(() => {
    if (!route || !sourceToken || !amount) return;
    const stepLabels = getRouteSteps(route);
    const initialSteps: StepState[] = stepLabels.map((label) => ({
      label,
      status: "pending",
    }));
    setSteps(initialSteps);
    setFlowDone(false);
    setFlowError(null);
    depositFiredRef.current = false;
    executeFromStep(0, route, stepLabels);
  }, [route, sourceToken, amount, executeFromStep]);

  // ─── Retry from failed step ───────────────────────────────────────────
  const handleRetry = useCallback(() => {
    if (currentStepIdx < 0 || !route) return;
    const stepLabels = getRouteSteps(route);
    executeFromStep(currentStepIdx, route, stepLabels);
  }, [currentStepIdx, route, executeFromStep]);

  // ─── Reset flow ───────────────────────────────────────────────────────
  const handleReset = useCallback(() => {
    setSourceToken(null);
    setSourceChainId(null);
    setAmount("");
    clearQuote();
    resetSwapStatus();
    resetBridge();
    setExecuting(false);
    setSteps([]);
    setCurrentStepIdx(-1);
    setFlowDone(false);
    setFlowError(null);
  }, [clearQuote, resetSwapStatus, resetBridge]);

  // ─── Computed ─────────────────────────────────────────────────────────
  const canDeposit =
    !!sourceToken &&
    !!amount &&
    !executing &&
    !flowDone &&
    (route !== "full" || !!quote);

  const formattedArcBalance =
    arcUsdcBalance !== undefined
      ? Number(formatUnits(arcUsdcBalance, 6)).toLocaleString(undefined, {
          maximumFractionDigits: 4,
        })
      : null;

  // ─── Render ───────────────────────────────────────────────────────────
  return (
    <div className="flex flex-col gap-4">
      {/* Success state */}
      {flowDone && (
        <div className="flex flex-col gap-3">
          <Alert className="border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950">
            <AlertDescription>
              <p className="text-sm font-medium text-green-700 dark:text-green-300">
                Deposit successful!
              </p>
              {vaultBalance !== undefined && (
                <p className="mt-1 text-xs text-green-600 dark:text-green-400">
                  Vault balance: {vaultBalance.toString()} value units
                </p>
              )}
            </AlertDescription>
          </Alert>
          {steps.length > 0 && <StepTracker steps={steps} />}
          <Button variant="outline" onClick={handleReset}>
            New deposit
          </Button>
        </div>
      )}

      {/* Input state (not done) */}
      {!flowDone && (
        <>
          {/* Token selector */}
          <div>
            <Label className="mb-1">From</Label>
            <Button
              variant="outline"
              className="flex w-full items-center justify-between font-normal"
              onClick={() => setSourceModalOpen(true)}
              disabled={executing}
            >
              {sourceToken ? (
                <span className="flex items-center gap-2">
                  {sourceToken.logoURI && (
                    <img
                      src={sourceToken.logoURI}
                      alt={sourceToken.symbol}
                      className="h-5 w-5 rounded-full"
                    />
                  )}
                  {sourceToken.symbol}
                  <span className="text-xs text-muted-foreground">
                    on{" "}
                    {allChains.find((c) => c.id === sourceChainId)?.name ??
                      `Chain ${sourceChainId}`}
                  </span>
                </span>
              ) : (
                <span className="text-muted-foreground">Select token to deposit...</span>
              )}
              <span className="text-muted-foreground">&rsaquo;</span>
            </Button>
          </div>

          {/* Route badge */}
          {routeBadge && (
            <div className="flex items-center gap-2">
              <Badge variant={routeBadge.variant}>
                {routeBadge.label}
              </Badge>
              {route === "direct" && formattedArcBalance !== null && (
                <span className="text-xs text-muted-foreground">
                  USDC on Arc: {formattedArcBalance}
                </span>
              )}
            </div>
          )}

          {/* Amount input */}
          {sourceToken && (
            <div>
              <div className="mb-1 flex items-center justify-between">
                <Label>
                  Amount{route === "direct" || route === "bridge" ? " (USDC)" : ""}
                </Label>
                <div className="flex items-center gap-2">
                  {sourceToken.amount && sourceToken.amount > BigInt(0) && (
                    <Button
                      variant="link"
                      size="sm"
                      className="h-auto p-0 text-xs"
                      onClick={() =>
                        setAmount(
                          formatUnits(sourceToken.amount!, sourceToken.decimals)
                        )
                      }
                    >
                      Max
                    </Button>
                  )}
                  {route === "full" && (
                    <Button
                      variant="ghost"
                      size="sm"
                      className="h-auto p-0 text-muted-foreground"
                      onClick={() => setShowSlippage(!showSlippage)}
                      title="Slippage settings"
                    >
                      <svg className="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.066 2.573c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.573 1.066c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.066-2.573c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                    </Button>
                  )}
                </div>
              </div>
              <Input
                type="text"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                placeholder="0.0"
                disabled={executing}
              />
              {sourceToken.amount !== undefined &&
                sourceToken.amount > BigInt(0) && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    Balance:{" "}
                    {Number(
                      formatUnits(sourceToken.amount, sourceToken.decimals)
                    ).toLocaleString(undefined, { maximumFractionDigits: 4 })}
                  </p>
                )}
            </div>
          )}

          {/* Slippage settings */}
          {showSlippage && route === "full" && (
            <Card className="bg-muted/50">
              <CardContent className="p-3">
                <Label className="mb-1 text-xs">Slippage tolerance (%)</Label>
                <div className="flex items-center gap-2">
                  {["0.1", "0.5", "1.0"].map((val) => (
                    <Button
                      key={val}
                      variant={slippage === val ? "default" : "secondary"}
                      size="sm"
                      className="h-7 px-2 text-xs"
                      onClick={() => setSlippage(val)}
                    >
                      {val}%
                    </Button>
                  ))}
                  <Input
                    type="text"
                    value={slippage}
                    onChange={(e) => setSlippage(e.target.value)}
                    className="h-7 w-16 text-xs"
                  />
                </div>
              </CardContent>
            </Card>
          )}

          {/* LI.FI Quote display (full route only) */}
          {route === "full" && amount && sourceToken && (
            <Card className="bg-muted/50">
              <CardContent className="p-3">
                {quoteLoading ? (
                  <p className="text-xs text-muted-foreground">Fetching quote...</p>
                ) : quoteError ? (
                  <p className="text-xs text-destructive">{quoteError}</p>
                ) : quote ? (
                  <div className="flex flex-col gap-1">
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-muted-foreground">You receive</span>
                      <span className="text-sm font-medium">
                        ~
                        {Number(
                          formatUnits(BigInt(quote.toAmount), 6)
                        ).toLocaleString(undefined, {
                          maximumFractionDigits: 4,
                        })}{" "}
                        USDC
                      </span>
                    </div>
                    {quote.gasCostUSD && (
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-muted-foreground">Gas cost</span>
                        <span className="text-xs text-muted-foreground">
                          ${quote.gasCostUSD}
                        </span>
                      </div>
                    )}
                    <div className="flex items-center justify-between">
                      <span className="text-xs text-muted-foreground">Est. time</span>
                      <span className="text-xs text-muted-foreground">
                        ~{Math.ceil(quote.executionDuration / 60)} min (swap) + ~15 min (bridge)
                      </span>
                    </div>
                  </div>
                ) : null}
              </CardContent>
            </Card>
          )}

          {/* Balance display for bridge route */}
          {route === "bridge" && sourceToken && sourceChainId && (
            <Card className="bg-muted/50">
              <CardContent className="p-3">
                <div className="flex items-center justify-between">
                  <span className="text-xs text-muted-foreground">Route</span>
                  <span className="text-xs text-muted-foreground">
                    {getCircleBridgeConfig(sourceChainId)?.label} → Arc Testnet via Circle CCTP
                  </span>
                </div>
                <div className="mt-1 flex items-center justify-between">
                  <span className="text-xs text-muted-foreground">Est. time</span>
                  <span className="text-xs text-muted-foreground">~15 min</span>
                </div>
              </CardContent>
            </Card>
          )}

          {/* Step tracker (during execution) */}
          {steps.length > 0 && <StepTracker steps={steps} />}

          {/* Error display */}
          {flowError && (
            <Alert variant="destructive">
              <AlertDescription>
                {flowError.length > 200
                  ? flowError.slice(0, 200) + "..."
                  : flowError}
              </AlertDescription>
            </Alert>
          )}

          {/* Action buttons */}
          <div className="flex items-center gap-3">
            {flowError && !executing && (
              <Button variant="destructive" onClick={handleRetry}>
                Retry
              </Button>
            )}
            {!flowError && (
              <Button onClick={handleDeposit} disabled={!canDeposit}>
                {executing ? "Depositing..." : "Deposit"}
              </Button>
            )}
          </div>
        </>
      )}

      {/* Token selector modal */}
      <TokenSelectorModal
        isOpen={sourceModalOpen}
        onClose={() => setSourceModalOpen(false)}
        onSelect={handleSourceSelect}
        chains={allChains}
        tokensByChain={allTokensByChain}
        isLoading={tokensLoading}
        loadBalancesForChain={loadBalancesForChain}
        loadAllBalances={loadAllBalances}
        loadingBalancesChainId={loadingBalancesChainId}
      />
    </div>
  );
}
