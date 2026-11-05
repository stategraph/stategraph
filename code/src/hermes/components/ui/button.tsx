import * as React from "react"
import { Slot } from "@radix-ui/react-slot"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

const buttonVariants = cva(
  "inline-flex cursor-pointer items-center justify-center gap-2 whitespace-nowrap text-sm font-medium transition-colors duration-150 disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg:not([class*='size-'])]:size-4 shrink-0 [&_svg]:shrink-0 outline-none",
  {
    variants: {
      variant: {
        default: "bg-[var(--sg-accent-button)] text-white hover:bg-[var(--sg-accent-button-hover)] rounded-[var(--sg-button-radius)]",
        destructive:
          "bg-[var(--sg-error)] text-white hover:bg-[#e62958] rounded-[var(--sg-button-radius)]",
        outline:
          "border border-[var(--sg-border)] bg-[var(--sg-bg-2)] text-[var(--sg-text)] hover:bg-[var(--sg-bg-1)] rounded-[var(--sg-button-radius)]",
        secondary:
          "bg-[var(--sg-bg-2)] text-[var(--sg-text)] hover:bg-[var(--sg-bg-1)] rounded-[var(--sg-button-radius)]",
        ghost:
          "text-[var(--sg-text-muted)] hover:bg-[var(--sg-bg-2)] hover:text-[var(--sg-text)] rounded-[var(--sg-button-radius)]",
        link: "text-[var(--sg-accent)] underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2 has-[>svg]:px-3",
        sm: "h-8 gap-1.5 px-3 has-[>svg]:px-2.5",
        lg: "h-10 px-6 has-[>svg]:px-4",
        icon: "size-9",
        "icon-sm": "size-8",
        "icon-lg": "size-10",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Button({
  className,
  variant,
  size,
  asChild = false,
  ...props
}: React.ComponentProps<"button"> &
  VariantProps<typeof buttonVariants> & {
    asChild?: boolean
  }) {
  const Comp = asChild ? Slot : "button"

  return (
    <Comp
      data-slot="button"
      className={cn(buttonVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Button, buttonVariants }
