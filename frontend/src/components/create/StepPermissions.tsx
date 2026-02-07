"use client";

import { useWizard } from "./WizardContext";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Alert, AlertDescription } from "@/components/ui/alert";

function PermissionBadge({ label }: { label: string }) {
  return (
    <Badge variant="secondary" className="gap-2 font-normal">
      <div className="h-2 w-2 rounded-full bg-green-500" />
      {label}
    </Badge>
  );
}

export function StepPermissions() {
  const { state, setState } = useWizard();

  return (
    <div className="flex flex-col gap-8">
      <Alert>
        <AlertDescription>
          Permissions control what actions you and your users can perform with
          this stablecoin. Core permissions are always enabled.
        </AlertDescription>
      </Alert>

      {/* Always-on permissions */}
      <div>
        <h3 className="text-sm font-medium uppercase tracking-wider text-muted-foreground mb-4">
          Always Enabled
        </h3>
        <Card>
          <CardContent className="flex flex-col gap-3 p-5">
            <PermissionBadge label="Owner can mint tokens" />
            <PermissionBadge label="Users can hold tokens" />
            <PermissionBadge label="Users can receive transfers" />
          </CardContent>
        </Card>
      </div>

      {/* Configurable */}
      <div>
        <h3 className="text-sm font-medium uppercase tracking-wider text-muted-foreground mb-4">
          Optional
        </h3>
        <Card>
          <CardContent className="p-5">
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1">
                <p className="font-medium">Users can mint</p>
                <p className="text-sm text-muted-foreground mt-0.5">
                  Allow users to deposit collateral and mint stablecoins
                  themselves, without the owner doing it for them.
                </p>
              </div>
              <Switch
                checked={state.usersCanMint}
                onCheckedChange={(checked) =>
                  setState({ usersCanMint: checked })
                }
              />
            </div>
          </CardContent>
        </Card>
      </div>

      <p className="text-sm text-muted-foreground">
        Users will be added after deployment through the management dashboard.
      </p>
    </div>
  );
}
