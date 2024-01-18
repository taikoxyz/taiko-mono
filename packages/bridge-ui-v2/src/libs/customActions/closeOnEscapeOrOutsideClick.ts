/**
 * Svelte custom action to close a modal on escape or outside click
 *
 * Example usage:
 * <div use:closeOnEscapeOrOutsideClick={{ enabled: modalIsOpen, callback: closeModal }}></div>
 *
 * @export
 * @param {HTMLElement} node
 * @param {{ enabled: boolean; callback: () => void }} { enabled, callback }
 * @return {*}
 */

export function closeOnEscapeOrOutsideClick(
  node: HTMLElement,
  { enabled, callback }: { enabled: boolean; callback: () => void },
) {
  const handleEvent = (event: Event) => {
    if (!enabled) {
      return;
    }

    // Handle click: check if the click is outside the node
    if (event.type === 'click' && !node.contains(event.target as Node)) {
      callback();
    }

    // Handle keydown: check if the key is Escape
    if (event.type === 'keydown' && (event as KeyboardEvent).key === 'Escape') {
      callback();
    }
  };

  // Use capturing phase to ensure the event is captured as it goes down the DOM tree
  document.addEventListener('click', handleEvent, true);
  document.addEventListener('keydown', handleEvent, true);

  return {
    destroy() {
      document.removeEventListener('click', handleEvent, true);
      document.removeEventListener('keydown', handleEvent, true);
    },
    update({ enabled: newEnabled, callback: newCb }: { enabled: boolean; callback: () => void }) {
      enabled = newEnabled;
      callback = newCb;
    },
  };
}
