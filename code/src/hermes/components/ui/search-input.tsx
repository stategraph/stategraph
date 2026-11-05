import * as React from "react"
import { Search } from "lucide-react"

import { Input } from "@/components/ui/input"
import { cn } from "@/lib/utils"

/**
 * Text input with a leading search icon: the filter box of the Admin users
 * list, shared so every settings list filters with the same look. Takes the
 * same props as `Input`; `className` applies to the input itself.
 */
function SearchInput({ className, ...props }: React.ComponentProps<"input">) {
  return (
    <div className="relative flex-1">
      <Search
        className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4"
        style={{ color: "var(--sg-text-muted)" }}
      />
      <Input className={cn("pl-9", className)} {...props} />
    </div>
  )
}

export { SearchInput }
