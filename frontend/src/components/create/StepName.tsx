"use client";

import { useWizard } from "./WizardContext";
import { useAppKitAccount } from "@reown/appkit/react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent } from "@/components/ui/card";
import { Alert, AlertDescription } from "@/components/ui/alert";

export function StepName() {
  const { state, setState } = useWizard();
  const { address } = useAppKitAccount();

  const symbolValid =
    state.tokenSymbol.length === 0 ||
    /^[A-Za-z0-9]{2,5}$/.test(state.tokenSymbol);

  return (
    <div className="flex flex-col gap-8 sm:flex-row sm:gap-12">
      <div className="flex-1 flex flex-col gap-6">
        <div>
          <Label htmlFor="tokenName" className="mb-2">
            Token Name
          </Label>
          <Input
            id="tokenName"
            type="text"
            placeholder="e.g. SalaryCoin"
            value={state.tokenName}
            onChange={(e) => setState({ tokenName: e.target.value })}
          />
        </div>
        <div>
          <Label htmlFor="tokenSymbol" className="mb-2">
            Token Symbol
          </Label>
          <Input
            id="tokenSymbol"
            type="text"
            placeholder="e.g. SAL"
            maxLength={5}
            value={state.tokenSymbol}
            onChange={(e) =>
              setState({ tokenSymbol: e.target.value.toUpperCase() })
            }
            className={!symbolValid ? "border-destructive" : ""}
          />
          {!symbolValid && (
            <p className="mt-1 text-sm text-destructive">
              Symbol must be 2-5 alphanumeric characters.
            </p>
          )}
        </div>
        <Alert>
          <AlertDescription>
            You&apos;re creating a new stablecoin instance on the protocol. Each
            instance gets its own ERC20 token that you control. Think of it like
            creating a branded dollar for your specific use case.
          </AlertDescription>
        </Alert>
      </div>

      {/* Live preview */}
      <div className="sm:w-56 shrink-0">
        <Card>
          <CardContent className="p-5">
            <p className="text-xs text-muted-foreground mb-3 uppercase tracking-wider">
              Preview
            </p>
            <p className="text-lg font-semibold">
              {state.tokenName || "Token Name"}
            </p>
            <p className="text-sm text-muted-foreground">
              {state.tokenSymbol || "SYM"}
            </p>
            <div className="mt-4 pt-4 border-t border-border">
              <p className="text-xs text-muted-foreground">Owner</p>
              <p className="text-xs text-muted-foreground font-mono truncate">
                {address}
              </p>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
