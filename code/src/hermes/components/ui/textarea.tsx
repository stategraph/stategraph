import * as React from "react"

import { cn } from "@/lib/utils"

function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        "placeholder:text-[var(--sg-text-dim)] selection:bg-[var(--sg-accent)] selection:text-white",
        "bg-[var(--sg-bg-2)] border-[var(--sg-border)]",
        "w-full min-w-0 rounded-[var(--sg-input-radius)] border px-3 py-2 text-base text-[var(--sg-text)] transition-colors outline-none",
        "disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50",
        "md:text-sm",
        "focus:border-[var(--sg-accent)] focus:ring-2 focus:ring-[var(--sg-accent)]",
        "resize-none",
        className
      )}
      {...props}
    />
  )
}

export { Textarea }
