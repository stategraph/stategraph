import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { AlertCircle } from 'lucide-react';

export interface DashboardErrorAlertProps {
  error: string | Error;
  onRetry?: () => void;
}

export function DashboardErrorAlert({ error, onRetry }: DashboardErrorAlertProps) {
  const errorMessage = typeof error === 'string' ? error : error.message;

  return (
    <div className="mx-6 mt-6">
      <Alert variant="destructive" className="bg-[var(--sg-error-bg)] border-[var(--sg-error)]">
        <AlertCircle className="h-4 w-4" />
        <AlertTitle className="text-[var(--sg-error)]">Failed to load dashboard</AlertTitle>
        <AlertDescription className="text-[var(--sg-text-muted)] mt-2">
          {errorMessage}
          {onRetry && (
            <>
              {' '}
              <button
                onClick={onRetry}
                className="underline hover:text-[var(--sg-text)] transition-colors"
              >
                Try again
              </button>
            </>
          )}
        </AlertDescription>
      </Alert>
    </div>
  );
}
