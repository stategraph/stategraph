import { Badge } from '@/components/ui/badge';
import { getProviderDisplay } from '@/app/(console)/types/loader';

interface ProviderBadgeProps {
  provider: string;
  variant?: 'default' | 'secondary' | 'outline';
}

/**
 * ProviderBadge - Display provider name as a styled badge
 */
export function ProviderBadge({ provider, variant = 'secondary' }: ProviderBadgeProps) {
  return (
    <Badge variant={variant} className="sg-metadata uppercase">
      {getProviderDisplay(provider)}
    </Badge>
  );
}
