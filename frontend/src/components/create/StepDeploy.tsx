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
import { mediumPegAbi } from "@/contracts/abis/mediumPeg";
import {
  getContractAddress,
  ARC_CHAIN_ID,
  ARBITRUM_CHAIN_ID,
  WA_ARB_USDC_VAULT,
} from "@/contracts/addresses";
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
  const walletChainId = caipAddress
    ? parseInt(caipAddress.split(":")[1])
    : undefined;

  const isYield = state.pegStyle === "yield";
  const targetChainId = isYield ? ARBITRUM_CHAIN_ID : ARC_CHAIN_ID;
  const addresses = getContractAddress(targetChainId);
  const contractAddress = isYield ? addresses?.mediumPeg : addresses?.hardPeg;
  const abi = isYield ? mediumPegAbi : hardPegAbi;

  const [appId, setAppId] = useState<bigint | null>(null);
  const [coinAddress, setCoinAddress] = useState<string | null>(null);
  const [settingVault, setSettingVault] = useState(false);
  const [vaultSet, setVaultSet] = useState(false);
  const [vaultError, setVaultError] = useState<string | null>(null);

  const appActions = Actions.MINT | Actions.HOLD;
  const userActions =
    Actions.HOLD |
    Actions.TRANSFER_DEST |
    (state.usersCanMint ? Actions.MINT : BigInt(0));

  const { switchChain } = useSwitchChain();
  const wrongNetwork = !contractAddress || walletChainId !== targetChainId;

  const {
    writeContract,
    writeContractAsync,
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

  // Decode RegisteredApp event from receipt
  useEffect(() => {
    if (!receipt?.logs) return;
    for (const log of receipt.logs) {
      try {
        const decoded = decodeEventLog({
          abi,
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
  }, [receipt, abi]);

  // For yield peg: call setVault after instance creation
  const {
    writeContractAsync: writeSetVaultAsync,
  } = useWriteContract();

  useEffect(() => {
    if (!isYield || appId === null || vaultSet || settingVault) return;

    (async () => {
      setSettingVault(true);
      try {
        await writeSetVaultAsync({
          address: contractAddress!,
          abi: mediumPegAbi,
          functionName: "setVault",
          args: [appId, WA_ARB_USDC_VAULT],
          chainId: ARBITRUM_CHAIN_ID,
        });
        setVaultSet(true);
      } catch (err) {
        setVaultError(
          err instanceof Error ? err.message : "Failed to set vault"
        );
      } finally {
        setSettingVault(false);
      }
    })();
  }, [isYield, appId, contractAddress, vaultSet, settingVault, writeSetVaultAsync]);

  const deploy = () => {
    if (!contractAddress) return;
    writeContract({
      address: contractAddress,
      abi,
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
      chainId: targetChainId,
    });
  };

  const error = writeError || receiptError;
  const chainLabel = isYield ? "Arbitrum" : "Arc Testnet";

  // For yield peg, wait for both instance creation and vault setup
  const fullyDone = isYield
    ? isSuccess && appId !== null && vaultSet
    : isSuccess && appId !== null;

  // Success state
  if (fullyDone) {
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
              <span className="font-mono">#{appId!.toString()}</span>
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
            <Separator />
            <div className="flex justify-between py-3">
              <span className="text-sm text-muted-foreground">Chain</span>
              <span>{chainLabel}</span>
            </div>
            {isYield && (
              <>
                <Separator />
                <div className="flex justify-between py-3">
                  <span className="text-sm text-muted-foreground">Vault</span>
                  <span className="font-mono text-sm">
                    {truncateAddress(WA_ARB_USDC_VAULT)}
                  </span>
                </div>
              </>
            )}
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
              setVaultSet(false);
              setVaultError(null);
              setStep(0);
            }}
          >
            Create Another
          </Button>
        </div>
      </div>
    );
  }

  // Vault setup in progress
  if (isSuccess && appId !== null && isYield && !vaultSet) {
    return (
      <div className="flex flex-col items-center gap-6 py-8">
        {vaultError ? (
          <>
            <div className="flex h-16 w-16 items-center justify-center rounded-full bg-destructive/10 text-3xl">
              !
            </div>
            <h2 className="text-xl font-bold">Vault Setup Failed</h2>
            <Alert variant="destructive" className="max-w-md">
              <AlertTitle>Error</AlertTitle>
              <AlertDescription>
                {vaultError.length > 200
                  ? vaultError.slice(0, 200) + "..."
                  : vaultError}
              </AlertDescription>
            </Alert>
            <Button
              onClick={() => {
                setVaultError(null);
                setSettingVault(false);
              }}
            >
              Retry Set Vault
            </Button>
          </>
        ) : (
          <>
            <div className="h-16 w-16 animate-spin rounded-full border-4 border-muted border-t-primary" />
            <h2 className="text-xl font-bold">
              {settingVault
                ? "Setting up vault..."
                : "Confirm vault setup in wallet..."}
            </h2>
            <p className="text-sm text-muted-foreground">
              Configuring the Aave waArbUSDCn vault for your instance.
            </p>
          </>
        )}
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
            token contract on {chainLabel}.
          </p>
          {wrongNetwork ? (
            <Button
              size="lg"
              variant="secondary"
              onClick={() => switchChain({ chainId: targetChainId })}
            >
              Switch to {chainLabel}
            </Button>
          ) : (
            <motion.div whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}>
              <Button size="lg" onClick={deploy}>
                Deploy Instance
              </Button>
            </motion.div>
          )}
        </>
      )}
    </div>
  );
}
