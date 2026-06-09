"use client";

// React port of src/components/Transactions/InsufficientFunds.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let modalOpen = false` (two-way bound) -> controllable `modalOpen`
//     prop + `onModalOpenChange`; also usable uncontrolled (the close button /
//     overlay / escape mutate it internally, matching the original which flips
//     `modalOpen` from within via `closeModal`).
//   - `crypto.randomUUID()` dialog id -> SSR-safe `useId()`.
//   - `use:closeOnEscapeOrOutsideClick` action -> `useCloseOnEscapeOrOutsideClick`
//     hook bound to the dialog ref.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - `$env/static/public` `PUBLIC_GUIDE_URL` -> `publicEnv.GUIDE_URL`.
//   - `on:click` -> `onClick`.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useId, useRef, useState } from "react";

import { ActionButton, CloseButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { publicEnv } from "@/config/env";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions/closeOnEscapeOrOutsideClick";
import { cn } from "@/lib/utils";
import { useTranslation } from "@/i18n/useTranslation";

export interface InsufficientFundsProps {
  /** Svelte `bind:modalOpen`. Controllable + uncontrolled. */
  modalOpen?: boolean;
  onModalOpenChange?: (open: boolean) => void;
}

export default function InsufficientFunds({
  modalOpen: modalOpenProp,
  onModalOpenChange,
}: InsufficientFundsProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe id replacing `crypto.randomUUID()` at script init.
  const dialogId = `dialog-${useId()}`;

  const dialogRef = useRef<HTMLDialogElement>(null);

  const isControlled = onModalOpenChange !== undefined;
  const [internalOpen, setInternalOpen] = useState(modalOpenProp ?? false);
  const modalOpen = isControlled ? (modalOpenProp ?? false) : internalOpen;

  const setModalOpen = (value: boolean) => {
    if (!isControlled) {
      setInternalOpen(value);
    }
    onModalOpenChange?.(value);
  };

  const closeModal = () => setModalOpen(false);

  useCloseOnEscapeOrOutsideClick(dialogRef, {
    enabled: modalOpen,
    callback: closeModal,
    uuid: dialogId,
  });

  return (
    <dialog
      ref={dialogRef}
      id={dialogId}
      className={cn("modal", modalOpen && "modal-open")}
    >
      <div className="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
        <CloseButton onClick={closeModal} />
        <div className="w-full space-y-6">
          <h3 className="title-body-bold mb-7">
            {t("transactions.actions.claim.dialog.title")}
          </h3>
          <div className="body-regular text-secondary-content mb-3 flex flex-col items-end">
            <div>{t("transactions.actions.claim.dialog.description")}</div>
          </div>

          <ActionButton priority="primary" onClick={closeModal}>
            <span className="body-bold">{t("common.ok")}</span>
          </ActionButton>
          <div className="flex justify-center">
            <a
              href={publicEnv.GUIDE_URL}
              target="_blank"
              rel="noreferrer"
              className="flex link py-[10px]"
            >
              {t("transactions.actions.claim.dialog.link")}
              <Icon type="arrow-top-right" />
            </a>
          </div>
        </div>
      </div>
      <button className="overlay-backdrop" data-modal-uuid={dialogId} />
    </dialog>
  );
}
