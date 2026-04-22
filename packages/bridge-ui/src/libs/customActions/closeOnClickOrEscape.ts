export function closeOnClickOrEscape(
  node: HTMLElement,
  { enabled, callback }: { enabled: boolean; callback: () => void },
) {
  let attached = false;

  const handleEvent = (event: Event) => {
    if (!enabled || !attached) return;

    if (event.type === 'click') {
      callback();
    }

    // For keydown events, check if the key is Escape
    if (event.type === 'keydown' && (event as KeyboardEvent).key === 'Escape') {
      callback();
    }
  };

  const attachListeners = () => {
    document.addEventListener('click', handleEvent, true);
    document.addEventListener('keydown', handleEvent, true);
    attached = true;
  };

  const detachListeners = () => {
    document.removeEventListener('click', handleEvent, true);
    document.removeEventListener('keydown', handleEvent, true);
    attached = false;
  };

  if (enabled) {
    setTimeout(attachListeners, 0); // Delay the attachment of listeners
  }

  return {
    destroy() {
      detachListeners();
    },
    update(newParams: { enabled: boolean; callback: () => void }) {
      if (enabled !== newParams.enabled) {
        enabled = newParams.enabled;
        enabled ? setTimeout(attachListeners, 0) : detachListeners();
      }
      callback = newParams.callback;
    },
  };
}
