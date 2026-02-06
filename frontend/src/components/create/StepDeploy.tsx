"use client";

import Link from "next/link";
import { useWizard } from "./WizardContext";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useWriteContract,
  useWaitForTransactionReceipt,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress } from "@/contracts/addresses";
import { Actions } from "@/contracts/actions";
import { decodeEventLog } from "viem";
import { useEffect, useState } from "react";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function StepDeploy() {
  const { state, setStep } = useWizard();
  const { caipAddress } = useAppKitAccount();
  const chainId = caipAddress ? parseInt(caipAddress.split(":")[1]) : undefined;

  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  const [appId, setAppId] = useState<bigint | null>(null);
  const [coinAddress, setCoinAddress] = useState<string | null>(null);

  const appActions = Actions.MINT | Actions.HOLD;
  const userActions =
    Actions.HOLD | Actions.TRANSFER_DEST | (state.usersCanMint ? Actions.MINT : BigInt(0));

  const { writeContract, data: txHash, isPending, error: writeError } = useWriteContract();

  const {
    isLoading: isConfirming,
    isSuccess,
    error: receiptError,
    data: receipt,
  } = useWaitForTransactionReceipt({ hash: txHash });

  useEffect(() => {
    if (!receipt?.logs) return;
    for (const log of receipt.logs) {
      try {
        const decoded = decodeEventLog({
          abi: hardPegAbi,
          data: log.data,
          topics: log.topics,
        });
        if (decoded.eventName === "RegisteredApp") {
          setAppId(decoded.args.id);
          setCoinAddress(decoded.args.coin);
        }
      } catch {
        // not the event we're looking for
      }
    }
  }, [receipt]);

  const deploy = () => {
    if (!contractAddress) return;
    writeContract({
      address: contractAddress,
      abi: hardPegAbi,
      functionName: "newInstance",
      args: [
        {
          name: state.tokenName,
          symbol: state.tokenSymbol,
          appActions,
          userActions,
          users: [],
          tokens: state.selectedCollateral,
        },
      ],
    });
  };

  const error = writeError || receiptError;

  // Success state
  if (isSuccess && appId !== null) {
    return (
      <div className="flex flex-col items-center gap-6 py-8">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-green-100 text-3xl dark:bg-green-900">
          {"\u2713"}
        </div>
        <h2 className="text-xl font-bold text-black dark:text-white">
          Instance Created!
        </h2>
        <div className="w-full rounded-xl border border-zinc-200 divide-y divide-zinc-100 px-5 dark:border-zinc-800 dark:divide-zinc-800">
          <div className="flex justify-between py-3">
            <span className="text-sm text-zinc-400">App ID</span>
            <span className="font-mono text-black dark:text-white">
              #{appId.toString()}
            </span>
          </div>
          <div className="flex justify-between py-3">
            <span className="text-sm text-zinc-400">Token Contract</span>
            <span className="font-mono text-sm text-black dark:text-white">
              {coinAddress ? truncateAddress(coinAddress) : "\u2014"}
            </span>
          </div>
          <div className="flex justify-between py-3">
            <span className="text-sm text-zinc-400">Token</span>
            <span className="text-black dark:text-white">
              {state.tokenName} ({state.tokenSymbol})
            </span>
          </div>
        </div>
        <div className="flex gap-3">
          <Link
            href="/"
            className="rounded-lg bg-blue-600 px-6 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-700"
          >
            View My Instances
          </Link>
          <button
            onClick={() => {
              setAppId(null);
              setCoinAddress(null);
              setStep(0);
            }}
            className="rounded-lg border border-zinc-200 px-6 py-3 text-sm font-medium text-black transition-colors hover:bg-zinc-50 dark:border-zinc-700 dark:text-white dark:hover:bg-zinc-800"
          >
            Create Another
          </button>
        </div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="flex flex-col items-center gap-6 py-8">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-red-100 text-3xl dark:bg-red-900">
          !
        </div>
        <h2 className="text-xl font-bold text-black dark:text-white">
          Deployment Failed
        </h2>
        <p className="text-sm text-red-600 text-center max-w-md">
          {error.message.length > 200
            ? error.message.slice(0, 200) + "..."
            : error.message}
        </p>
        <button
          onClick={() => setStep(4)}
          className="rounded-lg bg-blue-600 px-6 py-3 text-sm font-medium text-white transition-colors hover:bg-blue-700"
        >
          Back to Review
        </button>
      </div>
    );
  }

  // Deploying / confirming state
  return (
    <div className="flex flex-col items-center gap-6 py-8">
      {isPending || isConfirming ? (
        <>
          <div className="h-16 w-16 animate-spin rounded-full border-4 border-blue-200 border-t-blue-600" />
          <h2 className="text-xl font-bold text-black dark:text-white">
            {isPending
              ? "Confirm in your wallet..."
              : "Deploying your stablecoin..."}
          </h2>
          <p className="text-sm text-zinc-500">
            {isPending
              ? "Please approve the transaction in your wallet."
              : "Waiting for transaction confirmation."}
          </p>
        </>
      ) : (
        <>
          <h2 className="text-xl font-bold text-black dark:text-white">
            Ready to Deploy
          </h2>
          <p className="text-sm text-zinc-500 text-center max-w-md">
            Click below to submit the transaction. This will deploy your{" "}
            <span className="font-medium text-black dark:text-white">
              {state.tokenName} ({state.tokenSymbol})
            </span>{" "}
            token contract.
          </p>
          <button
            onClick={deploy}
            className="rounded-lg bg-blue-600 px-8 py-4 text-lg font-medium text-white transition-colors hover:bg-blue-700"
          >
            Deploy Instance
          </button>
        </>
      )}
    </div>
  );
}
