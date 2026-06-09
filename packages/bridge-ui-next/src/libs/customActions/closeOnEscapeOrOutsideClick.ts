"use client";

import { useEffect, useRef, type RefObject } from "react";

/**
 * React port of the original SvelteKit `closeOnEscapeOrOutsideClick` custom action.
 *
 * Closes a modal on Escape or on an outside click.
 *
 * Requires a reference to the modal node and a `uuid` to be passed in.
 *
 * Original Svelte usage:
 *
 * <dialog class="modal" use:closeOnEscapeOrOutsideClick={{ enabled: modalIsOpen, callback: closeModal, uuid: <YOUR_UUID> }}>
 *  -- modal content --
 * <div class="any class" data-modal-uuid={<YOUR_UUID>} /> // <--- Note: this needs to be in the dialog or parent to link the listener to the modal
 * </dialog>
 *
 * React usage:
 *
 * const ref = useRef<HTMLDialogElement>(null);
 * useCloseOnEscapeOrOutsideClick(ref, { enabled: modalIsOpen, callback: closeModal, uuid });
 * return <dialog ref={ref} id={uuid}>...</dialog>;
 *
 * Behavior is preserved verbatim from the original:
 *  - Listeners are attached to `document` in the CAPTURE phase (`true`), deferred
 *    via `setTimeout(..., 0)`.
 *  - On `click`: if the target's `data-modal-uuid` !== uuid AND the click is
 *    outside `node`, fire `callback()`. Else if the target's `data-modal-uuid`
 *    === uuid AND the target has the `overlay-backdrop` class, fire `callback()`.
 *  - On `keydown` Escape: fire `callback()` only if an element with `id === uuid`
 *    exists in the document.
 *
 * `callback` and `uuid` are read through refs so changing them never re-attaches
 * listeners — matching the original `update` which reassigned `callback`/`uuid`
 * without touching the listeners. Only `enabled` flips attach/detach.
 *
 * @param nodeRef Ref to the modal element (the original action's `node`).
 * @param params  `{ enabled, callback, uuid }`.
 */
export function useCloseOnEscapeOrOutsideClick(
  nodeRef: RefObject<HTMLElement | null>,
  {
    enabled,
    callback,
    uuid,
  }: { enabled: boolean; callback: () => void; uuid: string },
): void {
  const callbackRef = useRef(callback);
  const uuidRef = useRef(uuid);

  // Keep the latest callback/uuid in refs so changing them never re-attaches
  // listeners (mirrors the original `update` which reassigned `callback`/`uuid`
  // only). Synced in an effect to satisfy React 19's no-ref-writes-during-render
  // rule.
  useEffect(() => {
    callbackRef.current = callback;
    uuidRef.current = uuid;
  });

  useEffect(() => {
    if (!enabled) return;

    let attached = false;

    const handleEvent = (event: Event) => {
      if (!attached) return;
      const node = nodeRef.current;
      const currentUuid = uuidRef.current;
      const target = event.target as HTMLElement;

      // For click events, check if the click is outside the node and matches the UUID
      if (event.type === "click") {
        if (
          target.dataset.modalUuid !== currentUuid &&
          !(node && node.contains(target))
        ) {
          callbackRef.current();
        } else if (
          target.dataset.modalUuid === currentUuid &&
          target.classList.contains("overlay-backdrop")
        ) {
          callbackRef.current();
        }
      }

      // For keydown events, check if the key is Escape and the modal with the UUID is open
      if (
        event.type === "keydown" &&
        (event as KeyboardEvent).key === "Escape"
      ) {
        const modalElement = document.getElementById(currentUuid);
        if (modalElement) {
          callbackRef.current();
        }
      }
    };

    const attachListeners = () => {
      document.addEventListener("click", handleEvent, true);
      document.addEventListener("keydown", handleEvent, true);
      attached = true;
    };

    const detachListeners = () => {
      document.removeEventListener("click", handleEvent, true);
      document.removeEventListener("keydown", handleEvent, true);
      attached = false;
    };

    const timeoutId = setTimeout(attachListeners, 0); // Delay the attachment of listeners

    return () => {
      clearTimeout(timeoutId);
      detachListeners();
    };
  }, [enabled, nodeRef]);
}

export default useCloseOnEscapeOrOutsideClick;
