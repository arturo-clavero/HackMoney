"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import { formatUnits, parseUnits } from "viem";
import type { TokenAmount } from "@lifi/sdk";
import { useLifiTokens, useLifiQuote, useLifiExecution } from "@/hooks/useLifi";
import { TokenSelectorModal } from "./TokenSelectorModal";

export function CrossChainDeposit({ appId }: { appId: bigint }) {
  const { caipAddress, address } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;

  // ─── Token selection ────────────────────────────────────────────────────
  const [sourceModalOpen, setSourceModalOpen] = useState(false);
  const [destModalOpen, setDestModalOpen] = useState(false);
  const [sourceToken, setSourceToken] = useState<TokenAmount | null>(null);
  const [sourceChainId, setSourceChainId] = useState<number | null>(null);
  const [destToken, setDestToken] = useState<TokenAmount | null>(null);
  const [destChainId, setDestChainId] = useState<number | null>(null);
  const [amount, setAmount] = useState("");

  const { chains, tokensByChain, isLoading: tokensLoading, loadingBalancesChainId, load: loadTokens, loadBalancesForChain } = useLifiTokens(address);
  const { quote, isLoading: quoteLoading, error: quoteError, fetchQuote, clearQuote } = useLifiQuote();
  const { status: swapStatus, error: swapError, execute: executeSwap, resetStatus, setStatus: setSwapStatus } = useLifiExecution();

  // Eagerly load chains + tokens, preload connected chain balances
  useEffect(() => {
    loadTokens(chainId);
  }, [loadTokens, chainId]);

  const handleOpenSourceModal = useCallback(() => {
    setSourceModalOpen(true);
  }, []);

  const handleOpenDestModal = useCallback(() => {
    setDestModalOpen(true);
  }, []);

  const handleSourceSelect = useCallback((token: TokenAmount, tokenChainId: number) => {
    setSourceToken(token);
    setSourceChainId(tokenChainId);
    setAmount("");
    clearQuote();
    resetStatus();
  }, [clearQuote, resetStatus]);

  const handleDestSelect = useCallback((token: TokenAmount, tokenChainId: number) => {
    setDestToken(token);
    setDestChainId(tokenChainId);
    clearQuote();
    resetStatus();
  }, [clearQuote, resetStatus]);

  // ─── Auto-quote with debounce ───────────────────────────────────────────
  const debounceRef = useRef<ReturnType<typeof setTimeout>>();

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    if (!sourceToken || !sourceChainId || !destToken || !destChainId || !address || !amount) {
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
        toChain: destChainId,
        fromToken: sourceToken.address,
        toToken: destToken.address,
        fromAmount: rawAmount,
        fromAddress: address,
      });
    }, 500);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [sourceToken, sourceChainId, destToken, destChainId, address, amount, fetchQuote, clearQuote]);

  // ─── Execute ────────────────────────────────────────────────────────────
  const handleExecute = async () => {
    if (!quote || !address) return;
    try {
      await executeSwap(quote.route);
      setSwapStatus("done");
    } catch {
      // Error already set by useLifiExecution
    }
  };

  const isWorking = swapStatus === "swapping";

  const handleReset = () => {
    setAmount("");
    resetStatus();
    clearQuote();
  };

  // ─── Render ─────────────────────────────────────────────────────────────
  return (
    <div className="flex flex-col gap-4">
      {/* Source token */}
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          From
        </label>
        <button
          onClick={handleOpenSourceModal}
          className="flex w-full items-center justify-between rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black transition-colors hover:border-zinc-300 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white dark:hover:border-zinc-600"
        >
          {sourceToken ? (
            <span className="flex items-center gap-2">
              {sourceToken.logoURI && (
                <img src={sourceToken.logoURI} alt={sourceToken.symbol} className="h-5 w-5 rounded-full" />
              )}
              {sourceToken.symbol}
              <span className="text-xs text-zinc-400">
                on {chains.find((c) => c.id === sourceChainId)?.name ?? `Chain ${sourceChainId}`}
              </span>
            </span>
          ) : (
            <span className="text-zinc-400">Select source token...</span>
          )}
          <span className="text-zinc-400">&rsaquo;</span>
        </button>
      </div>

      {/* Destination token */}
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          To
        </label>
        <button
          onClick={handleOpenDestModal}
          className="flex w-full items-center justify-between rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black transition-colors hover:border-zinc-300 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white dark:hover:border-zinc-600"
        >
          {destToken ? (
            <span className="flex items-center gap-2">
              {destToken.logoURI && (
                <img src={destToken.logoURI} alt={destToken.symbol} className="h-5 w-5 rounded-full" />
              )}
              {destToken.symbol}
              <span className="text-xs text-zinc-400">
                on {chains.find((c) => c.id === destChainId)?.name ?? `Chain ${destChainId}`}
              </span>
            </span>
          ) : (
            <span className="text-zinc-400">Select destination token...</span>
          )}
          <span className="text-zinc-400">&rsaquo;</span>
        </button>
      </div>

      {/* Amount */}
      {sourceToken && destToken && (
        <div>
          <div className="mb-1 flex items-center justify-between">
            <label className="text-sm font-medium text-black dark:text-white">
              Amount
            </label>
            {sourceToken.amount && sourceToken.amount > BigInt(0) && (
              <button
                onClick={() => setAmount(formatUnits(sourceToken.amount!, sourceToken.decimals))}
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
              {Number(formatUnits(sourceToken.amount, sourceToken.decimals)).toLocaleString(undefined, {
                maximumFractionDigits: 4,
              })}
            </p>
          )}
        </div>
      )}

      {/* Quote display */}
      {amount && sourceToken && destToken && (
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
                  ~{Number(formatUnits(BigInt(quote.toAmount), destToken.decimals)).toLocaleString(undefined, { maximumFractionDigits: 4 })}{" "}
                  {destToken.symbol}
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

      {/* Error display */}
      {swapError && (
        <p className="text-xs text-red-500">
          {swapError.length > 200 ? swapError.slice(0, 200) + "..." : swapError}
        </p>
      )}

      {/* Progress */}
      {swapStatus === "swapping" && (
        <p className="text-xs text-blue-600 dark:text-blue-400">Swapping...</p>
      )}

      {/* Success */}
      {swapStatus === "done" && (
        <div className="flex flex-col gap-2">
          <p className="text-xs text-green-600 dark:text-green-400">
            Swap complete! Tokens are in your wallet.
          </p>
          <button
            onClick={handleReset}
            className="rounded-lg border border-zinc-200 px-4 py-2 text-sm text-zinc-600 transition-colors hover:bg-zinc-50 dark:border-zinc-700 dark:text-zinc-300 dark:hover:bg-zinc-800"
          >
            New swap
          </button>
        </div>
      )}

      {/* Execute button */}
      {swapStatus !== "done" && (
        <button
          onClick={handleExecute}
          disabled={!sourceToken || !destToken || !amount || isWorking || !quote}
          className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {isWorking ? "Swapping..." : "Swap"}
        </button>
      )}

      {/* Token selector modals */}
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
      <TokenSelectorModal
        isOpen={destModalOpen}
        onClose={() => setDestModalOpen(false)}
        onSelect={handleDestSelect}
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
