import { useState, useCallback, useRef } from 'react';

export function useDisclaimer() {
  const [isDisclaimerOpen, setIsDisclaimerOpen] = useState(false);
  const pendingActionRef = useRef<(() => void) | null>(null);

  const requireDisclaimer = useCallback((action: () => void) => {
    pendingActionRef.current = action;
    setIsDisclaimerOpen(true);
  }, []);

  const onAccept = useCallback(() => {
    setIsDisclaimerOpen(false);
    pendingActionRef.current?.();
    pendingActionRef.current = null;
  }, []);

  const onCancel = useCallback(() => {
    setIsDisclaimerOpen(false);
    pendingActionRef.current = null;
  }, []);

  return { isDisclaimerOpen, requireDisclaimer, onAccept, onCancel };
}
