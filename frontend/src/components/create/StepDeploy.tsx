"use client";

import Link from "next/link";
import { useWizard } from "./WizardContext";
import { useAppKitAccount } from "@reown/appkit/react";
import {
  useWriteContract,
  useWaitForTransactionReceipt,
  useSwitchChain,
} from "wagmi";
import { hardPegAbi } from "@/contracts/abis/hardPeg";
import { getContractAddress, ARC_CHAIN_ID } from "@/contracts/addresses";
import { Actions } from "@/contracts/actions";
import { decodeEventLog } from "viem";
import { useEffect, useState } from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";
import { Separator } from "@/components/ui/separator";
import { motion } from "@/components/motion";

function truncateAddress(addr: string) {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
}

export function StepDeploy() {
  const { state, setStep } = useWizard();
  const { caipAddress } = useAppKitAccount();
  const chainId = caipAddress
    ? parseInt(caipAddress.split(":")[1])
    : undefined;

  const addresses = chainId ? getContractAddress(chainId) : null;
  const contractAddress = addresses?.hardPeg;

  const [appId, setAppId] = useState<bigint | null>(null);
  const [coinAddress, setCoinAddress] = useState<string | null>(null);

  const appActions = Actions.MINT | Actions.HOLD;
  const userActions =
    Actions.HOLD |
    Actions.TRANSFER_DEST |
    (state.usersCanMint ? Actions.MINT : BigInt(0));

  const { switchChain } = useSwitchChain();
  const wrongNetwork = !contractAddress;

  const {
    writeContract,
    data: txHash,
    isPending,
    error: writeError,
  } = useWriteContract();

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
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ type: "spring", stiffness: 300, damping: 20 }}
          className="flex h-16 w-16 items-center justify-center rounded-full bg-green-100 text-3xl dark:bg-green-900"
        >
          {"\u2713"}
        </motion.div>
        <h2 className="text-xl font-bold">Instance Created!</h2>
        <Card className="w-full">
          <CardContent className="px-5 py-0">
            <div className="flex justify-between py-3">
              <span className="text-sm text-muted-foreground">App ID</span>
              <span className="font-mono">#{appId.toString()}</span>
            </div>
            <Separator />
            <div className="flex justify-between py-3">
              <span className="text-sm text-muted-foreground">
                Token Contract
              </span>
              <span className="font-mono text-sm">
                {coinAddress ? truncateAddress(coinAddress) : "\u2014"}
              </span>
            </div>
            <Separator />
            <div className="flex justify-between py-3">
              <span className="text-sm text-muted-foreground">Token</span>
              <span>
                {state.tokenName} ({state.tokenSymbol})
              </span>
            </div>
          </CardContent>
        </Card>
        <div className="flex gap-3">
          <Button asChild>
            <Link href="/">View My Instances</Link>
          </Button>
          <Button
            variant="outline"
            onClick={() => {
              setAppId(null);
              setCoinAddress(null);
              setStep(0);
            }}
          >
            Create Another
          </Button>
        </div>
      </div>
    );
  }

  // Error state
  if (error) {
    return (
      <div className="flex flex-col items-center gap-6 py-8">
        <div className="flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10 text-3xl">
          !
        </div>
        <h2 className="text-xl font-bold">Deployment Failed</h2>
        <Alert variant="destructive" className="max-w-md">
          <AlertTitle>Error</AlertTitle>
          <AlertDescription>
            {error.message.length > 200
              ? error.message.slice(0, 200) + "..."
              : error.message}
          </AlertDescription>
        </Alert>
        <Button onClick={() => setStep(4)}>Back to Review</Button>
      </div>
    );
  }

  // Deploying / confirming state
  return (
    <div className="flex flex-col items-center gap-6 py-8">
      {isPending || isConfirming ? (
        <>
          <div className="h-16 w-16 animate-spin rounded-full border-4 border-muted border-t-primary" />
          <h2 className="text-xl font-bold">
            {isPending
              ? "Confirm in your wallet..."
              : "Deploying your stablecoin..."}
          </h2>
          <p className="text-sm text-muted-foreground">
            {isPending
              ? "Please approve the transaction in your wallet."
              : "Waiting for transaction confirmation."}
          </p>
        </>
      ) : (
        <>
          <h2 className="text-xl font-bold">Ready to Deploy</h2>
          <p className="text-sm text-muted-foreground text-center max-w-md">
            Click below to submit the transaction. This will deploy your{" "}
            <span className="font-medium text-foreground">
              {state.tokenName} ({state.tokenSymbol})
            </span>{" "}
            token contract.
          </p>
          {wrongNetwork ? (
            <Button
              size="lg"
              variant="secondary"
              onClick={() => switchChain({ chainId: ARC_CHAIN_ID })}
            >
              Switch to Arc Testnet
            </Button>
          ) : (
            <Button size="lg" onClick={deploy}>
              Deploy Instance
            </Button>
          )}
        </>
      )}
    </div>
  );
}
