/**
 * Svelte custom action to close a modal on escape or outside click
 *
 * Requires a background element and an uuid to be passed in as params
 *
 * Example usage:
 *
 * <dialog class="modal" use:closeOnEscapeOrOutsideClick={{ enabled: modalIsOpen, callback: closeModal, uuid: <YOUR_UUID> }}>
 *  -- modal content --
 * <div class="any class" data-modal-uuid={<YOUR_UUID>} /> // <--- Note: this needs to be in the dialog or parent to link the listener to the modal
 * </dialog>
 *
 * @export
 * @param {HTMLElement} node
 * @param {{ enabled: boolean; callback: () => void; uuid: string}} { enabled, callback }
 * @return {*}
 */

export function closeOnEscapeOrOutsideClick(
  node: HTMLElement,
  { enabled, callback, uuid }: { enabled: boolean; callback: () => void; uuid: string },
) {
  let attached = false;

  const handleEvent = (event: Event) => {
    if (!enabled || !attached) return;
    const target = event.target as HTMLElement;

    // For click events, check if the click is outside the node and matches the UUID
    if (enabled && event.type === 'click') {
      if (target.dataset.modalUuid !== uuid && !node.contains(target)) {
        callback();
      } else if (target.dataset.modalUuid === uuid && target.classList.contains('overlay-backdrop')) {
        callback();
      }
    }

    // For keydown events, check if the key is Escape and the modal with the UUID is open
    if (event.type === 'keydown' && (event as KeyboardEvent).key === 'Escape') {
      const modalElement = document.getElementById(uuid);
      if (modalElement) {
        callback();
      }
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
    update(newParams: { enabled: boolean; callback: () => void; uuid: string }) {
      if (enabled !== newParams.enabled) {
        enabled = newParams.enabled;
        enabled ? setTimeout(attachListeners, 0) : detachListeners();
      }
      callback = newParams.callback;
      uuid = newParams.uuid;
    },
  };
}
