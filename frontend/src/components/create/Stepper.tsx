"use client";

import { useWizard } from "./WizardContext";

const STEPS = [
  "Name",
  "Peg Style",
  "Collateral",
  "Permissions",
  "Review",
  "Deploy",
];

export function Stepper() {
  const { step } = useWizard();

  return (
    <div className="flex items-center gap-2 w-full mb-10">
      {STEPS.map((label, i) => {
        const isCompleted = i < step;
        const isCurrent = i === step;
        return (
          <div key={label} className="flex items-center gap-2 flex-1">
            <div className="flex items-center gap-2 min-w-0">
              <div
                className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-medium transition-colors ${
                  isCompleted
                    ? "bg-green-600 text-white"
                    : isCurrent
                      ? "bg-blue-600 text-white"
                      : "bg-zinc-200 text-zinc-500 dark:bg-zinc-800 dark:text-zinc-500"
                }`}
              >
                {isCompleted ? "\u2713" : i + 1}
              </div>
              <span
                className={`text-sm truncate hidden sm:block ${
                  isCurrent
                    ? "font-medium text-black dark:text-white"
                    : "text-zinc-400 dark:text-zinc-600"
                }`}
              >
                {label}
              </span>
            </div>
            {i < STEPS.length - 1 && (
              <div
                className={`h-px flex-1 ${
                  i < step
                    ? "bg-green-600"
                    : "bg-zinc-200 dark:bg-zinc-800"
                }`}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}
