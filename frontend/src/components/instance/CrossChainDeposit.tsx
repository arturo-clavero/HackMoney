"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
  useReadContracts,
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import {
  erc20Abi,
  formatUnits,
  parseUnits,
  type Address,
} from "viem";
import type { TokenAmount } from "@lifi/sdk";
import { useLifiTokens, useLifiQuote, useLifiExecution } from "@/hooks/useLifi";
import { TokenSelectorModal } from "./TokenSelectorModal";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function CrossChainDeposit({ appId }: { appId: bigint }) {
  const { caipAddress, address } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;
  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  // ─── Collateral selection (destination) ─────────────────────────────────
  const [selectedCollateral, setSelectedCollateral] = useState<Address | "">("");

  const { data: collateralList } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getGlobalCollateralList",
    query: { enabled: !!contractAddress },
  });

  const allowedChecks = useReadContracts({
    contracts: (collateralList ?? []).map((token) => ({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "isAppCollateralAllowed" as const,
      args: [appId, token] as const,
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

  const enabledTokens = (collateralList ?? []).filter(
    (_, i) => allowedChecks.data?.[i]?.result === true
  );

  // Auto-select if only one collateral
  useEffect(() => {
    if (enabledTokens.length === 1 && !selectedCollateral) {
      setSelectedCollateral(enabledTokens[0]);
    }
  }, [enabledTokens, selectedCollateral]);

  // Get collateral decimals
  const { data: collateralDecimals } = useReadContract({
    address: selectedCollateral as Address,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: !!selectedCollateral },
  });

  // ─── Source token selection ─────────────────────────────────────────────
  const [modalOpen, setModalOpen] = useState(false);
  const [sourceToken, setSourceToken] = useState<TokenAmount | null>(null);
  const [sourceChainId, setSourceChainId] = useState<number | null>(null);
  const [amount, setAmount] = useState("");

  const { chains, tokensByChain, isLoading: tokensLoading, load: loadTokens } = useLifiTokens(address);
  const { quote, isLoading: quoteLoading, error: quoteError, fetchQuote, clearQuote } = useLifiQuote();
  const { status: swapStatus, setStatus: setSwapStatus, error: swapError, setError: setSwapError, execute: executeSwap, resetStatus } = useLifiExecution();

  // Load tokens when modal opens
  const handleOpenModal = useCallback(() => {
    if (chains.length === 0) {
      loadTokens();
    }
    setModalOpen(true);
  }, [chains.length, loadTokens]);

  const handleTokenSelect = useCallback((token: TokenAmount, tokenChainId: number) => {
    setSourceToken(token);
    setSourceChainId(tokenChainId);
    setAmount("");
    clearQuote();
    resetStatus();
  }, [clearQuote, resetStatus]);

  // ─── Is this a direct deposit? ──────────────────────────────────────────
  const isDirectDeposit =
    sourceToken &&
    sourceChainId === chainId &&
    selectedCollateral &&
    sourceToken.address.toLowerCase() === (selectedCollateral as string).toLowerCase();

  // ─── Auto-quote with debounce ───────────────────────────────────────────
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (
      !sourceToken ||
      !sourceChainId ||
      !selectedCollateral ||
      !chainId ||
      !address ||
      !amount ||
      isDirectDeposit
    ) {
      clearQuote();
      return;
    }

    // Parse amount to raw
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
        toChain: chainId,
        fromToken: sourceToken.address,
        toToken: selectedCollateral as string,
        fromAmount: rawAmount,
        fromAddress: address,
      });
    }, 500);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [sourceToken, sourceChainId, selectedCollateral, chainId, address, amount, isDirectDeposit, fetchQuote, clearQuote]);

  // ─── Contract writes (approve + deposit) ────────────────────────────────
  const {
    writeContract,
    isPending: writePending,
    data: txHash,
    error: writeError,
    reset: resetWrite,
  } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: txSuccess } =
    useWaitForTransactionReceipt({ hash: txHash });

  // After approve success → trigger deposit
  useEffect(() => {
    if (txSuccess && swapStatus === "approving") {
      setSwapStatus("depositing");
      resetWrite();
      // Trigger deposit
      if (!contractAddress || !selectedCollateral || !amount) return;
      const decimals = collateralDecimals ?? 18;
      let rawAmount: bigint;
      if (isDirectDeposit) {
        rawAmount = parseUnits(amount, sourceToken!.decimals);
      } else {
        // Use the amount received from the swap (toAmountMin from quote)
        rawAmount = BigInt(quote?.toAmountMin ?? "0");
      }
      writeContract({
        address: contractAddress,
        abi: hardPegAbi,
        functionName: "deposit",
        args: [appId, selectedCollateral as Address, rawAmount],
      });
    }
  }, [txSuccess, swapStatus]);

  // After deposit success
  useEffect(() => {
    if (txSuccess && swapStatus === "depositing") {
      setSwapStatus("done");
    }
  }, [txSuccess, swapStatus]);

  // ─── Execute ────────────────────────────────────────────────────────────
  const handleExecute = async () => {
    if (!contractAddress || !selectedCollateral || !address) return;
    setSwapError(null);

    if (isDirectDeposit) {
      // Direct: approve → deposit
      setSwapStatus("approving");
      const rawAmount = parseUnits(amount, sourceToken!.decimals);
      writeContract({
        address: selectedCollateral as Address,
        abi: erc20Abi,
        functionName: "approve",
        args: [contractAddress, rawAmount],
      });
    } else {
      // Swap via LI.FI, then approve → deposit
      if (!quote) return;
      try {
        await executeSwap(quote.route);
        // Swap done — now approve the received collateral
        setSwapStatus("approving");
        resetWrite();
        // Read the user's balance of the collateral to approve the right amount
        const decimals = collateralDecimals ?? 18;
        const rawAmount = BigInt(quote.toAmountMin);
        writeContract({
          address: selectedCollateral as Address,
          abi: erc20Abi,
          functionName: "approve",
          args: [contractAddress, rawAmount],
        });
      } catch {
        // Error already set by useLifiExecution
      }
    }
  };

  const isWorking =
    swapStatus === "swapping" ||
    swapStatus === "approving" ||
    swapStatus === "depositing" ||
    writePending ||
    isConfirming;

  const handleReset = () => {
    setAmount("");
    resetStatus();
    resetWrite();
    clearQuote();
  };

  // ─── Render ─────────────────────────────────────────────────────────────
  return (
    <div className="flex flex-col gap-4">
      {/* Destination collateral */}
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          Deposit As
        </label>
        <select
          value={selectedCollateral}
          onChange={(e) => {
            setSelectedCollateral(e.target.value as Address);
            clearQuote();
            resetStatus();
            resetWrite();
          }}
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        >
          <option value="">Select collateral...</option>
          {enabledTokens.map((token) => {
            const idx = (collateralList ?? []).indexOf(token);
            const symbol =
              tokenSymbols.data?.[idx]?.result ?? truncateAddress(token);
            return (
              <option key={token} value={token}>
                {symbol as string}
              </option>
            );
          })}
        </select>
      </div>

      {/* Source token */}
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          Pay With
        </label>
        <button
          onClick={handleOpenModal}
          disabled={!selectedCollateral}
          className="flex w-full items-center justify-between rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black transition-colors hover:border-zinc-300 focus:border-blue-500 focus:outline-none disabled:cursor-not-allowed disabled:opacity-50 dark:border-zinc-700 dark:bg-zinc-900 dark:text-white dark:hover:border-zinc-600"
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
                on {chains.find((c) => c.id === sourceChainId)?.name ?? `Chain ${sourceChainId}`}
              </span>
            </span>
          ) : (
            <span className="text-zinc-400">Select token...</span>
          )}
          <span className="text-zinc-400">&rsaquo;</span>
        </button>
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
                  setAmount(formatUnits(sourceToken.amount!, sourceToken.decimals))
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
          {sourceToken.amount !== undefined && sourceToken.amount > BigInt(0) && (
            <p className="mt-1 text-xs text-zinc-400">
              Balance:{" "}
              {Number(formatUnits(sourceToken.amount, sourceToken.decimals)).toLocaleString(
                undefined,
                { maximumFractionDigits: 4 }
              )}
            </p>
          )}
        </div>
      )}

      {/* Quote display */}
      {amount && sourceToken && !isDirectDeposit && (
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
                  ~{Number(formatUnits(BigInt(quote.toAmount), collateralDecimals ?? 18)).toLocaleString(undefined, { maximumFractionDigits: 4 })}{" "}
                  {tokenSymbols.data?.[(collateralList ?? []).indexOf(selectedCollateral as Address)]?.result as string ?? ""}
                </span>
              </div>
              {quote.gasCostUSD && (
                <div className="flex items-center justify-between">
                  <span className="text-xs text-zinc-500">Gas cost</span>
                  <span className="text-xs text-zinc-400">${quote.gasCostUSD}</span>
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

      {/* Direct deposit indicator */}
      {amount && isDirectDeposit && (
        <div className="rounded-lg bg-green-50 p-3 text-xs text-green-700 dark:bg-green-950 dark:text-green-300">
          Direct deposit — no swap required
        </div>
      )}

      {/* Error display */}
      {(writeError || swapError) && (
        <p className="text-xs text-red-500">
          {(() => {
            const msg = writeError?.message ?? swapError ?? "";
            return msg.length > 200 ? msg.slice(0, 200) + "..." : msg;
          })()}
        </p>
      )}

      {/* Progress indicator */}
      {swapStatus !== "idle" && swapStatus !== "error" && (
        <div className="flex items-center gap-3 text-xs">
          {!isDirectDeposit && (
            <span className={swapStatus === "swapping" ? "text-blue-600 dark:text-blue-400" : swapStatus === "idle" ? "text-zinc-400" : "text-green-600 dark:text-green-400"}>
              {swapStatus === "swapping" ? "Swapping..." : swapStatus !== "idle" ? "Swapped" : "Swap"}
            </span>
          )}
          <span className={swapStatus === "approving" ? "text-blue-600 dark:text-blue-400" : ["depositing", "done"].includes(swapStatus) ? "text-green-600 dark:text-green-400" : "text-zinc-400"}>
            {swapStatus === "approving" ? (writePending ? "Confirm..." : isConfirming ? "Approving..." : "Approve") : ["depositing", "done"].includes(swapStatus) ? "Approved" : "Approve"}
          </span>
          <span className={swapStatus === "depositing" ? "text-blue-600 dark:text-blue-400" : swapStatus === "done" ? "text-green-600 dark:text-green-400" : "text-zinc-400"}>
            {swapStatus === "depositing" ? (writePending ? "Confirm..." : isConfirming ? "Depositing..." : "Deposit") : swapStatus === "done" ? "Done!" : "Deposit"}
          </span>
        </div>
      )}

      {/* Success */}
      {swapStatus === "done" && (
        <div className="flex flex-col gap-2">
          <p className="text-xs text-green-600 dark:text-green-400">
            Deposit successful!
          </p>
          <button
            onClick={handleReset}
            className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-600 transition-colors hover:bg-zinc-50 dark:border-zinc-700 dark:text-zinc-300 dark:hover:bg-zinc-800"
          >
            New deposit
          </button>
        </div>
      )}

      {/* Execute button */}
      {swapStatus !== "done" && (
        <button
          onClick={handleExecute}
          disabled={
            !selectedCollateral ||
            !sourceToken ||
            !amount ||
            isWorking ||
            (!isDirectDeposit && !quote)
          }
          className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isWorking
            ? swapStatus === "swapping"
              ? "Swapping..."
              : swapStatus === "approving"
                ? writePending
                  ? "Confirm in wallet..."
                  : "Approving..."
                : swapStatus === "depositing"
                  ? writePending
                    ? "Confirm in wallet..."
                    : "Depositing..."
                  : "Processing..."
            : isDirectDeposit
              ? "Approve & Deposit"
              : "Swap & Deposit"}
        </button>
      )}

      {/* Token selector modal */}
      <TokenSelectorModal
        isOpen={modalOpen}
        onClose={() => setModalOpen(false)}
        onSelect={handleTokenSelect}
        chains={chains}
        tokensByChain={tokensByChain}
        isLoading={tokensLoading}
        connectedChainId={chainId}
      />
    </div>
  );
}
