'use client';

import { Button } from '@/components/ui';

export default function ErrorResetButton({ reset }: { reset: () => void }) {
  return (
    <Button onClick={reset} variant="outline">
      Try again
    </Button>
  );
}
