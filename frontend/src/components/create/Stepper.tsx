"use client";

import { useWizard } from "./WizardContext";
import { motion } from "@/components/motion";

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
              <motion.div
                initial={false}
                animate={{
                  scale: isCurrent ? 1.1 : 1,
                  backgroundColor: isCompleted
                    ? "var(--color-green-600, #16a34a)"
                    : isCurrent
                      ? "var(--color-primary, #2563eb)"
                      : "var(--color-muted, #e4e4e7)",
                }}
                transition={{ type: "spring", stiffness: 300, damping: 20 }}
                className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-sm font-medium text-primary-foreground"
              >
                {isCompleted ? (
                  <motion.span
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    transition={{
                      type: "spring",
                      stiffness: 400,
                      damping: 15,
                    }}
                  >
                    &#10003;
                  </motion.span>
                ) : (
                  <span
                    className={
                      isCompleted || isCurrent
                        ? "text-white"
                        : "text-muted-foreground"
                    }
                  >
                    {i + 1}
                  </span>
                )}
              </motion.div>
              <span
                className={`text-sm truncate hidden sm:block ${
                  isCurrent
                    ? "font-medium text-foreground"
                    : "text-muted-foreground"
                }`}
              >
                {label}
              </span>
            </div>
            {i < STEPS.length - 1 && (
              <div
                className={`h-px flex-1 transition-colors ${
                  i < step ? "bg-green-600" : "bg-border"
                }`}
              />
            )}
          </div>
        );
      })}
    </div>
  );
}
