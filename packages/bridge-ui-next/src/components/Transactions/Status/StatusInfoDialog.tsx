"use client";

// React port of
// components/Transactions/Status/StatusInfoDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let modalOpen = false` (two-way bound) -> controllable `modalOpen`
//     prop + `onModalOpenChange`; also usable uncontrolled (the trigger button
//     opens it internally, matching the original which mutates `modalOpen` from
//     within via openModal/closeModal).
//   - `export let noIcon = false` -> typed `noIcon` prop.
//   - `crypto.randomUUID()` dialog id -> SSR-safe `useId()`.
//   - `<svelte:window on:keydown>` -> window keydown effect (Escape closes).
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - `on:click` / `on:focus` -> `onClick` / `onFocus`.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useEffect, useId, useState } from "react";

import { CloseButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";

export interface StatusInfoDialogProps {
  /** Svelte `bind:modalOpen`. Controllable + uncontrolled. */
  modalOpen?: boolean;
  onModalOpenChange?: (open: boolean) => void;
  noIcon?: boolean;
}

const classes = {
  headline:
    "text-center text-base font-bold leading-[24px] tracking-[0.08px] pb-[5px] pt-[25px]",
  content: "text-sm font-normal leading-5",
};

export default function StatusInfoDialog({
  modalOpen: modalOpenProp,
  onModalOpenChange,
  noIcon = false,
}: StatusInfoDialogProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe id replacing `crypto.randomUUID()` at script init.
  const dialogId = `dialog-${useId()}`;

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
  const openModal = () => setModalOpen(true);

  const closeModalIfClickedOutside = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  };

  // <svelte:window on:keydown={closeModalIfKeyDown} />
  useEffect(() => {
    const closeModalIfKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeModal();
      }
    };
    window.addEventListener("keydown", closeModalIfKeyDown);
    return () => window.removeEventListener("keydown", closeModalIfKeyDown);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isControlled]);

  return (
    <>
      <button
        aria-haspopup="dialog"
        aria-controls={dialogId}
        aria-expanded={modalOpen}
        onClick={openModal}
        onFocus={openModal}
        className=" ml-[4px]"
      >
        {!noIcon && <Icon type="question-circle" />}
      </button>

      <dialog
        id={dialogId}
        className={cn("modal", { "modal-open": modalOpen })}
      >
        <div className="modal-box bg-neutral-background text-primary-content text-center max-w-[565px]">
          <div className="w-full flex justify-end">
            <CloseButton onClick={closeModal} />
          </div>
          <div className="w-full">
            <h1 className="title-body-bold">
              {t("transactions.status.dialog.title")}
            </h1>
          </div>
          <div className="inline-flex flex-col px-[37px] text-base">
            <br />
            {t("transactions.status.dialog.description")}
            <h4 className={classes.headline}>
              {t("transactions.status.processing.name")}
            </h4>
            {t("transactions.status.processing.description")}
            <h4 className={classes.headline}>
              {t("transactions.status.claim.name")}
            </h4>
            {t("transactions.status.claim.description")}
            <h4 className={classes.headline}>
              {t("transactions.status.claimed.name")}
            </h4>
            {t("transactions.status.claimed.description")}
            <h4 className={classes.headline}>
              {t("transactions.status.retry.name")}
            </h4>
            {t("transactions.status.retry.description")}
            <h4 className={classes.headline}>
              {t("transactions.status.release.name")}
            </h4>
            {t("transactions.status.release.description")}
            <h4 className={classes.headline}>
              {t("transactions.status.failed.name")}
            </h4>
            {t("transactions.status.failed.description")}
          </div>
        </div>
        {/* We catch key events above */}
        {}
        <div
          role="button"
          tabIndex={0}
          className="overlay-backdrop"
          onClick={closeModalIfClickedOutside}
        />
      </dialog>
    </>
  );
}
