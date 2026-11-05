import * as React from "react"

import { cn } from "@/lib/utils"

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        "file:text-[var(--sg-text)] placeholder:text-[var(--sg-text-dim)] selection:bg-[var(--sg-accent)] selection:text-white",
        "bg-[var(--sg-bg-2)] border-[var(--sg-border)]",
        "h-[var(--sg-input-height)] w-full min-w-0 rounded-[var(--sg-input-radius)] border px-3 py-1 text-base text-[var(--sg-text)] transition-colors outline-none",
        "file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium",
        "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50",
        "md:text-sm",
        "focus:border-[var(--sg-accent)] focus:ring-2 focus:ring-[var(--sg-accent)]",
        className
      )}
      {...props}
    />
  )
}

export { Input }
