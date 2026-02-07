"use client";

import { useState, useEffect } from "react";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useReadContract,
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
  maxUint256,
} from "viem";
import { DepositFlow } from "./DepositFlow";

type Tab = "deposit" | "mint" | "redeem" | "withdraw";

export function VaultOperations({ appId }: { appId: bigint }) {
  const [activeTab, setActiveTab] = useState<Tab>("deposit");

  const tabs: { key: Tab; label: string }[] = [
    { key: "deposit", label: "Deposit" },
    { key: "mint", label: "Mint" },
    { key: "redeem", label: "Redeem" },
    { key: "withdraw", label: "Withdraw" },
  ];

  return (
    <div className="rounded-xl border border-zinc-200 dark:border-zinc-800">
      <div className="border-b border-zinc-200 px-5 py-3 dark:border-zinc-800">
        <h2 className="font-semibold text-black dark:text-white">
          Vault Operations
        </h2>
      </div>
      <div className="flex border-b border-zinc-200 dark:border-zinc-800">
        {tabs.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`flex-1 px-4 py-2.5 text-sm font-medium transition-colors ${
              activeTab === tab.key
                ? "border-b-2 border-blue-600 text-blue-600 dark:text-blue-400"
                : "text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300"
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>
      <div className="p-5">
        {activeTab === "deposit" && <DepositFlow appId={appId} />}
        {activeTab === "mint" && <MintTab appId={appId} />}
        {activeTab === "redeem" && <RedeemTab appId={appId} />}
        {activeTab === "withdraw" && <WithdrawTab appId={appId} />}
      </div>
    </div>
  );
}

// ─── Mint Tab ────────────────────────────────────────────────────────────────

const ARC_CHAIN_ID = 5042002;

function MintTab({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const [recipient, setRecipient] = useState("");
  const [amount, setAmount] = useState("");

  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
  });

  const { writeContract, isPending, data: txHash, error: writeError } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  useEffect(() => {
    if (isSuccess) refetchVault();
  }, [isSuccess, refetchVault]);

  const handleMint = () => {
    if (!contractAddress) return;
    const to = (recipient.trim() || address) as Address;
    const rawAmount = amount === "max" ? maxUint256 : parseUnits(amount, 18);
    writeContract({
      address: contractAddress,
      abi: hardPegAbi,
      functionName: "mint",
      args: [appId, to, rawAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking = isPending || isConfirming;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          Recipient
        </label>
        <input
          type="text"
          value={recipient}
          onChange={(e) => setRecipient(e.target.value)}
          placeholder={address ?? "0x..."}
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        />
        <p className="mt-1 text-xs text-zinc-400">
          Leave blank to mint to your own wallet.
        </p>
      </div>

      <div>
        <div className="mb-1 flex items-center justify-between">
          <label className="text-sm font-medium text-black dark:text-white">
            Amount
          </label>
          <button
            onClick={() => setAmount("max")}
            className="text-xs text-blue-600 hover:underline dark:text-blue-400"
          >
            Max
          </button>
        </div>
        <input
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        />
        {vaultBalance !== undefined && (
          <p className="mt-1 text-xs text-zinc-400">
            Vault balance: {vaultBalance.toString()} value units
          </p>
        )}
      </div>

      {writeError && (
        <p className="text-xs text-red-500">
          {writeError.message.length > 200
            ? writeError.message.slice(0, 200) + "..."
            : writeError.message}
        </p>
      )}

      {isSuccess && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Mint successful!
        </p>
      )}

      <button
        onClick={handleMint}
        disabled={!amount || isWorking}
        className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isPending
          ? "Confirm in wallet..."
          : isConfirming
            ? "Minting..."
            : "Mint"}
      </button>
    </div>
  );
}

// ─── Redeem Tab ──────────────────────────────────────────────────────────────

function RedeemTab({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const [amount, setAmount] = useState("");

  // Get coin address from app config
  const { data: appConfig } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getAppConfig",
    args: [appId],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress },
  });

  const coinAddress = appConfig?.coin as Address | undefined;

  // Get user's coin balance
  const { data: coinBalance, refetch: refetchCoin } = useReadContract({
    address: coinAddress,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!coinAddress && !!address },
  });

  const { writeContract, isPending, data: txHash, error: writeError } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  useEffect(() => {
    if (isSuccess) refetchCoin();
  }, [isSuccess, refetchCoin]);

  const handleRedeem = () => {
    if (!coinAddress || !amount) return;
    const rawAmount = parseUnits(amount, 18);
    writeContract({
      address: contractAddress!,
      abi: hardPegAbi,
      functionName: "redeam",
      args: [coinAddress, rawAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking = isPending || isConfirming;

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-lg bg-blue-50 p-3 text-xs text-blue-800 dark:bg-blue-950 dark:text-blue-200">
        Redeeming burns your stablecoins and returns a pro-rata basket of all
        collateral in the pool.
      </div>

      <div>
        <label className="mb-1 block text-sm font-medium text-black dark:text-white">
          Amount
        </label>
        <input
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        />
        {coinBalance !== undefined && (
          <p className="mt-1 text-xs text-zinc-400">
            Coin balance: {formatUnits(coinBalance, 18)}
          </p>
        )}
      </div>

      {writeError && (
        <p className="text-xs text-red-500">
          {writeError.message.length > 200
            ? writeError.message.slice(0, 200) + "..."
            : writeError.message}
        </p>
      )}

      {isSuccess && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Redeem successful!
        </p>
      )}

      <button
        onClick={handleRedeem}
        disabled={!amount || isWorking}
        className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isPending
          ? "Confirm in wallet..."
          : isConfirming
            ? "Redeeming..."
            : "Redeem"}
      </button>
    </div>
  );
}

// ─── Withdraw Tab ────────────────────────────────────────────────────────────

function WithdrawTab({ appId }: { appId: bigint }) {
  const { address } = useAppKitAccount();
  const addresses = getContractAddress(ARC_CHAIN_ID);
  const contractAddress = addresses?.hardPeg;

  const [amount, setAmount] = useState("");

  const { data: vaultBalance, refetch: refetchVault } = useReadContract({
    address: contractAddress,
    abi: hardPegAbi,
    functionName: "getVaultBalance",
    args: [appId, address as Address],
    chainId: ARC_CHAIN_ID,
    query: { enabled: !!contractAddress && !!address },
  });

  const { writeContract, isPending, data: txHash, error: writeError } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash: txHash,
  });

  useEffect(() => {
    if (isSuccess) refetchVault();
  }, [isSuccess, refetchVault]);

  const handleWithdraw = () => {
    if (!contractAddress || !amount) return;
    const valueAmount =
      amount === "max" ? maxUint256 : BigInt(amount);
    writeContract({
      address: contractAddress,
      abi: hardPegAbi,
      functionName: "withdrawCollateral",
      args: [appId, valueAmount],
      chainId: ARC_CHAIN_ID,
    });
  };

  const isWorking = isPending || isConfirming;

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-lg bg-blue-50 p-3 text-xs text-blue-800 dark:bg-blue-950 dark:text-blue-200">
        Withdraw returns a pro-rata basket of collateral from the pool,
        proportional to the value units withdrawn.
      </div>

      <div>
        <div className="mb-1 flex items-center justify-between">
          <label className="text-sm font-medium text-black dark:text-white">
            Amount (value units)
          </label>
          <button
            onClick={() => setAmount("max")}
            className="text-xs text-blue-600 hover:underline dark:text-blue-400"
          >
            Max
          </button>
        </div>
        <input
          type="text"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          placeholder="0.0"
          className="w-full rounded-lg border border-zinc-200 bg-white px-3 py-2 text-sm text-black placeholder-zinc-400 focus:border-blue-500 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-white"
        />
        {vaultBalance !== undefined && (
          <p className="mt-1 text-xs text-zinc-400">
            Vault balance: {vaultBalance.toString()} value units
          </p>
        )}
      </div>

      {writeError && (
        <p className="text-xs text-red-500">
          {writeError.message.length > 200
            ? writeError.message.slice(0, 200) + "..."
            : writeError.message}
        </p>
      )}

      {isSuccess && (
        <p className="text-xs text-green-600 dark:text-green-400">
          Withdrawal successful!
        </p>
      )}

      <button
        onClick={handleWithdraw}
        disabled={!amount || isWorking}
        className="rounded-lg bg-blue-600 px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {isPending
          ? "Confirm in wallet..."
          : isConfirming
            ? "Withdrawing..."
            : "Withdraw"}
      </button>
    </div>
  );
}
