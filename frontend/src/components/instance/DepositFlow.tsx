"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useWriteContract,
  useWaitForTransactionReceipt,
  useSwitchChain,
} from "wagmi";
import {
  erc20Abi,
  formatUnits,
  parseUnits,
  type Address,
} from "viem";
import type { TokenAmount } from "@lifi/sdk";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress, USDC_ADDRESSES } from "@/contracts/addresses";
import { useLifiTokens, useLifiQuote, useLifiExecution } from "@/hooks/useLifi";
import { useBridgeToArc } from "@/hooks/useBridgeToArc";
import { TokenSelectorModal } from "./TokenSelectorModal";

// ─── Constants ──────────────────────────────────────────────────────────────

const ARB_CHAIN_ID = 42161;
const ARB_USDC = USDC_ADDRESSES[ARB_CHAIN_ID];
const ARB_SEPOLIA_CHAIN_ID = 421614;
const ARB_SEPOLIA_USDC = USDC_ADDRESSES[ARB_SEPOLIA_CHAIN_ID];
const ARC_CHAIN_ID = 5042002;
const ARC_USDC = USDC_ADDRESSES[ARC_CHAIN_ID];

type Phase = 1 | 2 | 3;

const PHASE_LABELS = ["Swap to USDC", "Bridge to Arc", "Deposit to Vault"];

// ─── Phase Indicator ────────────────────────────────────────────────────────

function PhaseIndicator({
  currentPhase,
  completedPhases,
  onPhaseClick,
}: {
  currentPhase: Phase;
  completedPhases: Set<number>;
  onPhaseClick: (phase: Phase) => void;
}) {
  return (
    <div className="mb-6 flex items-center justify-between">
      {[1, 2, 3].map((phase, idx) => {
        const isCompleted = completedPhases.has(phase);
        const isCurrent = currentPhase === phase;

        return (
          <div key={phase} className="flex flex-1 items-center">
            <button
              onClick={() => onPhaseClick(phase as Phase)}
              className="flex flex-col items-center gap-1.5"
            >
              <div
                className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium transition-colors ${
                  isCompleted
                    ? "bg-green-600 text-white"
                    : isCurrent
                      ? "bg-blue-600 text-white"
                      : "bg-zinc-200 text-zinc-400 dark:bg-zinc-700 dark:text-zinc-500"
                }`}
              >
                {isCompleted ? (
                  <svg
                    className="h-4 w-4"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M5 13l4 4L19 7"
                    />
                  </svg>
                ) : (
                  phase
                )}
              </div>
              <span
                className={`text-xs font-medium ${
                  isCompleted
                    ? "text-green-600 dark:text-green-400"
                    : isCurrent
                      ? "text-blue-600 dark:text-blue-400"
                      : "text-zinc-400 dark:text-zinc-500"
                }`}
              >
                {PHASE_LABELS[idx]}
              </span>
            </button>
            {idx < 2 && (
              <div
                className={`mx-2 h-px flex-1 ${
                  completedPhases.has(phase)
                    ? "bg-green-600"
                    : "bg-zinc-200 dark:bg-zinc-700"
                }`}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}

// ─── Phase 1: LiFi Swap ────────────────────────────────────────────────────

function SwapPhase({
  onComplete,
  onSkip,
}: {
  onComplete: () => void;
  onSkip: () => void;
}) {
  const { caipAddress, address } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;

  const [sourceModalOpen, setSourceModalOpen] = useState(false);
  const [sourceToken, setSourceToken] = useState<TokenAmount | null>(null);
  const [sourceChainId, setSourceChainId] = useState<number | null>(null);
  const [amount, setAmount] = useState("");

  const {
    chains,
    tokensByChain,
    isLoading: tokensLoading,
    loadingBalancesChainId,
    load: loadTokens,
    loadBalancesForChain,
  } = useLifiTokens(address);

  const {
    quote,
    isLoading: quoteLoading,
    error: quoteError,
    fetchQuote,
    clearQuote,
  } = useLifiQuote();

  const {
    status: swapStatus,
    error: swapError,
    execute: executeSwap,
    resetStatus,
    setStatus: setSwapStatus,
  } = useLifiExecution();

  // Eagerly load chains + tokens, preload connected chain balances
  useEffect(() => {
    loadTokens(chainId);
  }, [loadTokens, chainId]);

  const handleSourceSelect = useCallback(
    (token: TokenAmount, tokenChainId: number) => {
      setSourceToken(token);
      setSourceChainId(tokenChainId);
      setAmount("");
      clearQuote();
      resetStatus();
    },
    [clearQuote, resetStatus]
  );

  // ─── Auto-quote with debounce ─────────────────────────────────────────
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (!sourceToken || !sourceChainId || !address || !amount) {
      clearQuote();
      return;
    }

    let rawAmount: string;
    try {
      rawAmount = parseUnits(amount, sourceToken.decimals).toString();
      if (rawAmount === "0") return;
    } catch {
      return;
    }

    debounceRef.current = setTimeout(() => {
      fetchQuote({
        fromChain: sourceChainId,
        toChain: ARB_CHAIN_ID,
        fromToken: sourceToken.address,
        toToken: ARB_USDC,
        fromAmount: rawAmount,
        fromAddress: address,
      });
    }, 500);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [sourceToken, sourceChainId, address, amount, fetchQuote, clearQuote]);

  // ─── Execute swap ─────────────────────────────────────────────────────
  const handleExecute = async () => {
    if (!quote || !address) return;
    try {
      await executeSwap(quote.route);
      setSwapStatus("done");
    } catch {
      // Error already set by useLifiExecution
    }
  };

  // Auto-advance on success
  useEffect(() => {
    if (swapStatus === "done") {
      const timer = setTimeout(onComplete, 1500);
      return () => clearTimeout(timer);
    }
  }, [swapStatus, onComplete]);

  const isWorking = swapStatus === "swapping";

  return (
    <div className="flex flex-col gap-4">
      {/* Source token picker */}
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          From
        </label>
        <button
          onClick={() => setSourceModalOpen(true)}
          className="flex w-full items-center justify-between rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black transition-colors hover:border-zinc-300 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white dark:hover:border-zinc-600"
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
              <span className="text-xs text-zinc-400">
                on{" "}
                {chains.find((c) => c.id === sourceChainId)?.name ??
                  `Chain ${sourceChainId}`}
              </span>
            </span>
          ) : (
            <span className="text-zinc-400">Select source token...</span>
          )}
          <span className="text-zinc-400">&rsaquo;</span>
        </button>
      </div>

      {/* Destination (static) */}
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          To
        </label>
        <div className="flex w-full items-center rounded-lg border border-zinc-200 bg-zinc-50 px-3 py-2 text-sm text-black dark:border-zinc-700 dark:bg-zinc-800/50 dark:text-white">
          <span className="flex items-center gap-2">
            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-blue-100 text-[10px] font-bold text-blue-700 dark:bg-blue-900 dark:text-blue-300">
              U
            </span>
            USDC
            <span className="text-xs text-zinc-400">on Arbitrum</span>
          </span>
        </div>
      </div>

      {/* Amount */}
      {sourceToken && (
        <div>
          <div className="mb-1 flex items-center justify-between">
            <label className="text-sm font-medium text-black dark:text-white">
              Amount
            </label>
            {sourceToken.amount && sourceToken.amount > BigInt(0) && (
              <button
                onClick={() =>
                  setAmount(
                    formatUnits(sourceToken.amount!, sourceToken.decimals)
                  )
                }
                className="text-xs text-blue-600 hover:underline dark:text-blue-400"
              >
                Max
              </button>
            )}
          </div>
          <input
            type="text"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="0.0"
            className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
          />
          {sourceToken.amount !== undefined &&
            sourceToken.amount > BigInt(0) && (
              <p className="mt-1 text-xs text-zinc-400">
                Balance:{" "}
                {Number(
                  formatUnits(sourceToken.amount, sourceToken.decimals)
                ).toLocaleString(undefined, { maximumFractionDigits: 4 })}
              </p>
            )}
        </div>
      )}

      {/* Quote display */}
      {amount && sourceToken && (
        <div className="rounded-lg border border-zinc-200 bg-zinc-50 p-3 dark:border-zinc-700 dark:bg-zinc-800/50">
          {quoteLoading ? (
            <p className="text-xs text-zinc-400">Fetching quote...</p>
          ) : quoteError ? (
            <p className="text-xs text-red-500">{quoteError}</p>
          ) : quote ? (
            <div className="flex flex-col gap-1">
              <div className="flex items-center justify-between">
                <span className="text-xs text-zinc-500">You receive</span>
                <span className="text-sm font-medium text-black dark:text-white">
                  ~
                  {Number(
                    formatUnits(BigInt(quote.toAmount), 6)
                  ).toLocaleString(undefined, { maximumFractionDigits: 4 })}{" "}
                  USDC
                </span>
              </div>
              {quote.gasCostUSD && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-zinc-500">Gas cost</span>
                  <span className="text-xs text-zinc-400">
                    ${quote.gasCostUSD}
                  </span>
                </div>
              )}
              <div className="flex items-center justify-between">
                <span className="text-xs text-zinc-500">Est. time</span>
                <span className="text-xs text-zinc-400">
                  ~{Math.ceil(quote.executionDuration / 60)} min
                </span>
              </div>
            </div>
          ) : null}
        </div>
      )}

      {/* Error */}
      {swapError && (
        <p className="text-xs text-red-500">
          {swapError.length > 200 ? swapError.slice(0, 200) + "..." : swapError}
        </p>
      )}

      {/* Progress */}
      {swapStatus === "swapping" && (
        <p className="text-xs text-blue-600 dark:text-blue-400">
          Swapping...
        </p>
      )}

      {/* Success */}
      {swapStatus === "done" && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Swap complete! Advancing to bridge...
        </p>
      )}

      {/* Actions */}
      {swapStatus !== "done" && (
        <div className="flex items-center gap-3">
          <button
            onClick={handleExecute}
            disabled={!sourceToken || !amount || isWorking || !quote}
            className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {isWorking ? "Swapping..." : "Swap"}
          </button>
          <button
            onClick={onSkip}
            className="text-sm text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300"
          >
            Skip &rarr;
          </button>
        </div>
      )}

      {/* Token selector modal */}
      <TokenSelectorModal
        isOpen={sourceModalOpen}
        onClose={() => setSourceModalOpen(false)}
        onSelect={handleSourceSelect}
        chains={chains}
        tokensByChain={tokensByChain}
        isLoading={tokensLoading}
        loadBalancesForChain={loadBalancesForChain}
        loadingBalancesChainId={loadingBalancesChainId}
        connectedChainId={chainId}
      />
    </div>
  );
}

// ─── Phase 2: Bridge to Arc ─────────────────────────────────────────────────

function BridgePhase({
  onComplete,
  onSkip,
}: {
  onComplete: () => void;
  onSkip: () => void;
}) {
  const { address, caipAddress } = useAppKitAccount();
  const currentChainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const { switchChainAsync } = useSwitchChain();
  const [amount, setAmount] = useState("");
  const [switchError, setSwitchError] = useState<string | null>(null);

  const { status, error, txHash, bridge, reset } = useBridgeToArc();

  // USDC balance on Arbitrum Sepolia
  const { data: arbUsdcBalance, refetch: refetchArbBalance } = useReadContract({
    address: ARB_SEPOLIA_USDC,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId: ARB_SEPOLIA_CHAIN_ID,
    query: { enabled: !!address },
  });

  const handleBridge = async () => {
    if (!amount) return;
    setSwitchError(null);

    // Switch to Arbitrum Sepolia if needed
    if (currentChainId !== ARB_SEPOLIA_CHAIN_ID) {
      try {
        await switchChainAsync({ chainId: ARB_SEPOLIA_CHAIN_ID });
      } catch {
        setSwitchError("Failed to switch to Arbitrum Sepolia");
        return;
      }
    }

    bridge(amount);
  };

  // Auto-advance on success
  useEffect(() => {
    if (status === "done") {
      refetchArbBalance();
      const timer = setTimeout(onComplete, 1500);
      return () => clearTimeout(timer);
    }
  }, [status, onComplete, refetchArbBalance]);

  const formattedBalance =
    arbUsdcBalance !== undefined
      ? Number(formatUnits(arbUsdcBalance, 6)).toLocaleString(undefined, {
          maximumFractionDigits: 4,
        })
      : null;

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-lg bg-blue-50 p-3 text-xs text-blue-800 dark:bg-blue-950 dark:text-blue-200">
        Bridge your USDC from Arbitrum Sepolia to Arc testnet using Circle CCTP.
        Get testnet USDC from{" "}
        <a
          href="https://faucet.circle.com"
          target="_blank"
          rel="noopener noreferrer"
          className="underline hover:text-blue-600"
        >
          faucet.circle.com
        </a>.
      </div>

      {/* Amount */}
      <div>
        <div className="mb-1 flex items-center justify-between">
          <label className="text-sm font-medium text-black dark:text-white">
            Amount (USDC)
          </label>
          {arbUsdcBalance !== undefined && arbUsdcBalance > BigInt(0) && (
            <button
              onClick={() => setAmount(formatUnits(arbUsdcBalance, 6))}
              className="text-xs text-blue-600 hover:underline dark:text-blue-400"
            >
              Max
            </button>
          )}
        </div>
        <input
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        />
        {formattedBalance !== null && (
          <p className="mt-1 text-xs text-zinc-400">
            USDC on Arbitrum Sepolia: {formattedBalance}
          </p>
        )}
      </div>

      {/* Error */}
      {(error || switchError) && (
        <p className="text-xs text-red-500">
          {(error || switchError)!.length > 200
            ? (error || switchError)!.slice(0, 200) + "..."
            : error || switchError}
        </p>
      )}

      {/* Progress */}
      {status === "bridging" && (
        <p className="text-xs text-blue-600 dark:text-blue-400">
          Bridging via Circle CCTP...
          {txHash && (
            <span className="ml-1 text-zinc-400">
              (tx: {txHash.slice(0, 10)}...)
            </span>
          )}
        </p>
      )}

      {/* Success */}
      {status === "done" && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Bridge complete! Advancing to deposit...
        </p>
      )}

      {/* Actions */}
      {status !== "done" && (
        <div className="flex items-center gap-3">
          <button
            onClick={handleBridge}
            disabled={!amount || status === "bridging"}
            className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
          >
            {status === "bridging" ? "Bridging..." : "Bridge"}
          </button>
          <button
            onClick={onSkip}
            className="text-sm text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300"
          >
            Skip &rarr;
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Phase 3: Approve + Deposit ─────────────────────────────────────────────

type DepositStep = "idle" | "switching-chain" | "approve-wallet" | "approving" | "deposit-wallet" | "depositing" | "done";

function DepositPhase({ appId }: { appId: bigint }) {
  const { address, caipAddress } = useAppKitAccount();
  const currentChainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const contractAddresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = contractAddresses?.hardPeg;
  const { switchChainAsync } = useSwitchChain();

  const [amount, setAmount] = useState("");
  const [step, setStep] = useState<DepositStep>("idle");
  const depositFiredRef = useRef(false);

  // USDC balance on Arc testnet
  const { data: arcUsdcBalance, refetch: refetchArcBalance } = useReadContract({
    address: ARC_USDC,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!address },
  });

  // Vault balance
  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
  });

  // Approve
  const {
    writeContract: writeApprove,
    isPending: approvePending,
    data: approveTxHash,
    error: approveError,
  } = useWriteContract();

  const {
    isLoading: approveConfirming,
    isSuccess: approveSuccess,
  } = useWaitForTransactionReceipt({ hash: approveTxHash });

  // Deposit
  const {
    writeContract: writeDeposit,
    isPending: depositPending,
    data: depositTxHash,
    error: depositError,
  } = useWriteContract();

  const {
    isLoading: depositConfirming,
    isSuccess: depositSuccess,
  } = useWaitForTransactionReceipt({ hash: depositTxHash });

  // Track step state
  useEffect(() => {
    if (approvePending) setStep("approve-wallet");
  }, [approvePending]);

  useEffect(() => {
    if (approveConfirming) setStep("approving");
  }, [approveConfirming]);

  useEffect(() => {
    if (depositPending) setStep("deposit-wallet");
  }, [depositPending]);

  useEffect(() => {
    if (depositConfirming) setStep("depositing");
  }, [depositConfirming]);

  // Auto-trigger deposit after approve succeeds (ref guard prevents double-fire)
  useEffect(() => {
    if (approveSuccess && contractAddress && amount && !depositFiredRef.current) {
      depositFiredRef.current = true;
      const rawAmount = parseUnits(amount, 6);
      writeDeposit({
        address: contractAddress,
        abi: hardPegAbi,
        functionName: "deposit",
        args: [appId, ARC_USDC, rawAmount],
        chainId: ARC_CHAIN_ID,
      });
    }
  }, [approveSuccess, contractAddress, amount, appId, writeDeposit]);

  // On deposit success
  useEffect(() => {
    if (depositSuccess) {
      setStep("done");
      refetchArcBalance();
      refetchVault();
    }
  }, [depositSuccess, refetchArcBalance, refetchVault]);

  // Reset step on errors
  useEffect(() => {
    if (approveError) setStep("idle");
  }, [approveError]);

  useEffect(() => {
    if (depositError) setStep("idle");
  }, [depositError]);

  const handleDeposit = async () => {
    if (!contractAddress || !amount) return;
    depositFiredRef.current = false;
    const rawAmount = parseUnits(amount, 6);

    // Switch to Arc testnet if needed
    if (currentChainId !== ARC_CHAIN_ID) {
      setStep("switching-chain");
      try {
        await switchChainAsync({ chainId: ARC_CHAIN_ID });
      } catch {
        setStep("idle");
        return;
      }
    }

    setStep("approve-wallet");
    writeApprove({
      address: ARC_USDC,
      abi: erc20Abi,
      functionName: "approve",
      args: [contractAddress, rawAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking =
    step === "switching-chain" ||
    step === "approve-wallet" ||
    step === "approving" ||
    step === "deposit-wallet" ||
    step === "depositing";

  const formattedArcBalance =
    arcUsdcBalance !== undefined
      ? Number(formatUnits(arcUsdcBalance, 6)).toLocaleString(undefined, {
          maximumFractionDigits: 4,
        })
      : null;

  const statusText: Record<DepositStep, string> = {
    idle: "",
    "switching-chain": "Switching to Arc testnet...",
    "approve-wallet": "Approve in wallet...",
    approving: "Approving...",
    "deposit-wallet": "Deposit in wallet...",
    depositing: "Depositing...",
    done: "",
  };

  const combinedError = approveError || depositError;

  return (
    <div className="flex flex-col gap-4">
      {/* Balances */}
      <div className="flex flex-col gap-1 rounded-lg border border-zinc-200 bg-zinc-50 p-3 dark:border-zinc-700 dark:bg-zinc-800/50">
        <div className="flex items-center justify-between">
          <span className="text-xs text-zinc-500">USDC on Arc</span>
          <span className="text-sm font-medium text-black dark:text-white">
            {formattedArcBalance ?? "..."}
          </span>
        </div>
        <div className="flex items-center justify-between">
          <span className="text-xs text-zinc-500">Vault balance</span>
          <span className="text-sm font-medium text-black dark:text-white">
            {vaultBalance !== undefined ? vaultBalance.toString() : "..."}{" "}
            <span className="text-xs text-zinc-400">value units</span>
          </span>
        </div>
      </div>

      {/* Amount */}
      <div>
        <div className="mb-1 flex items-center justify-between">
          <label className="text-sm font-medium text-black dark:text-white">
            Amount (USDC)
          </label>
          {arcUsdcBalance !== undefined && arcUsdcBalance > BigInt(0) && (
            <button
              onClick={() => setAmount(formatUnits(arcUsdcBalance, 6))}
              className="text-xs text-blue-600 hover:underline dark:text-blue-400"
            >
              Max
            </button>
          )}
        </div>
        <input
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        />
      </div>

      {/* Error */}
      {combinedError && (
        <p className="text-xs text-red-500">
          {combinedError.message.length > 200
            ? combinedError.message.slice(0, 200) + "..."
            : combinedError.message}
        </p>
      )}

      {/* Status text */}
      {isWorking && (
        <p className="text-xs text-blue-600 dark:text-blue-400">
          {statusText[step]}
        </p>
      )}

      {/* Success */}
      {step === "done" && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Deposit successful!
        </p>
      )}

      {/* Action */}
      <button
        onClick={handleDeposit}
        disabled={!amount || isWorking || step === "done"}
        className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
      >
        {isWorking ? statusText[step] : "Deposit"}
      </button>
    </div>
  );
}

// ─── Main Component ─────────────────────────────────────────────────────────

export function DepositFlow({ appId }: { appId: bigint }) {
  const [phase, setPhase] = useState<Phase>(1);
  const [completedPhases, setCompletedPhases] = useState<Set<number>>(
    new Set()
  );

  const completePhase = useCallback(
    (p: number) => {
      setCompletedPhases((prev) => {
        const next = new Set(prev);
        next.add(p);
        return next;
      });
    },
    []
  );

  const handlePhase1Complete = useCallback(() => {
    completePhase(1);
    setPhase(2);
  }, [completePhase]);

  const handlePhase2Complete = useCallback(() => {
    completePhase(2);
    setPhase(3);
  }, [completePhase]);

  const handleSkipToPhase2 = useCallback(() => {
    setPhase(2);
  }, []);

  const handleSkipToPhase3 = useCallback(() => {
    setPhase(3);
  }, []);

  return (
    <div>
      <PhaseIndicator
        currentPhase={phase}
        completedPhases={completedPhases}
        onPhaseClick={setPhase}
      />

      {phase === 1 && (
        <SwapPhase
          onComplete={handlePhase1Complete}
          onSkip={handleSkipToPhase2}
        />
      )}

      {phase === 2 && (
        <BridgePhase
          onComplete={handlePhase2Complete}
          onSkip={handleSkipToPhase3}
        />
      )}

      {phase === 3 && <DepositPhase appId={appId} />}
    </div>
  );
}
