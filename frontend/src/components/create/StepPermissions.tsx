"use client";

import { useWizard } from "./WizardContext";

function PermissionBadge({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-2">
      <div className="h-2 w-2 rounded-full bg-green-500" />
      <span className="text-sm text-black dark:text-white">{label}</span>
    </div>
  );
}

export function StepPermissions() {
  const { state, setState } = useWizard();

  return (
    <div className="flex flex-col gap-8">
      <div className="rounded-lg bg-blue-50 p-4 text-sm text-blue-800 dark:bg-blue-950 dark:text-blue-200">
        Permissions control what actions you and your users can perform with this
        stablecoin. Core permissions are always enabled.
      </div>

      {/* Always-on permissions */}
      <div>
        <h3 className="text-sm font-medium uppercase tracking-wider text-zinc-400 mb-4">
          Always Enabled
        </h3>
        <div className="rounded-xl border border-zinc-200 p-5 flex flex-col gap-3 dark:border-zinc-800">
          <PermissionBadge label="Owner can mint tokens" />
          <PermissionBadge label="Users can hold tokens" />
          <PermissionBadge label="Users can receive transfers" />
        </div>
      </div>

      {/* Configurable */}
      <div>
        <h3 className="text-sm font-medium uppercase tracking-wider text-zinc-400 mb-4">
          Optional
        </h3>
        <div className="rounded-xl border border-zinc-200 p-5 dark:border-zinc-800">
          <div className="flex items-start justify-between gap-4">
            <div className="flex-1">
              <p className="font-medium text-black dark:text-white">
                Users can mint
              </p>
              <p className="text-sm text-zinc-500 mt-0.5">
                Allow users to deposit collateral and mint stablecoins
                themselves, without the owner doing it for them.
              </p>
            </div>
            <button
              role="switch"
              aria-checked={state.usersCanMint}
              onClick={() => setState({ usersCanMint: !state.usersCanMint })}
              className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors ${
                state.usersCanMint
                  ? "bg-blue-600"
                  : "bg-zinc-300 dark:bg-zinc-700"
              }`}
            >
              <span
                className={`inline-block h-4 w-4 rounded-full bg-white transition-transform ${
                  state.usersCanMint ? "translate-x-6" : "translate-x-1"
                }`}
              />
            </button>
          </div>
        </div>
      </div>

      <p className="text-sm text-zinc-400">
        Users will be added after deployment through the management dashboard.
      </p>
    </div>
  );
}
