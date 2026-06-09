import type { ReactNode } from "react";

export interface ModalProps {
  /** Heading rendered as an `<h3>` at the top of the modal box. */
  title?: string;
  /** Default slot content rendered inside the modal box, below the title. */
  children?: ReactNode;
}

/**
 * React port of `components/Modal/Modal.svelte`.
 *
 * Faithful, presentation-only port. The original is a renderless daisyUI shell:
 * a `<dialog class="modal">` (no `open` attribute / visibility logic of its own)
 * wrapping a `.modal-box` with an `<h3>` title and the default slot, plus a
 * `.overlay-backdrop` sibling. DOM structure and class strings are preserved
 * verbatim for pixel parity.
 *
 * Svelte `export let title = ''` -> typed `title` prop (defaulted to '').
 * Svelte default `<slot />` -> `children`.
 */
export default function Modal({ title = "", children }: ModalProps) {
  return (
    <dialog className="modal">
      <div className="modal-box relative p-10 bg-primary-base-background">
        <h3 className="title-section-bold mb-2 text-primary-base-content">
          {title}
        </h3>
        {children}
      </div>

      <div className="overlay-backdrop" />
    </dialog>
  );
}
