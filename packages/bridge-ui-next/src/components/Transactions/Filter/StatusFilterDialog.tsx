"use client";

// React port of
// components/Transactions/Filter/StatusFilterDialog.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let selectedStatus = null` (two-way bound) -> controlled
//     `selectedStatus` prop + `onSelectedStatusChange`.
//   - `export let menuOpen = false` (two-way bound) -> controlled `menuOpen`
//     prop + `onMenuOpenChange`.
//   - `crypto.randomUUID()` dialog id -> SSR-safe `useId()`.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - `on:click` / `on:keydown` -> `onClick` / `onKeyDown`.
//   - `ActionButton` sibling assumed to follow the COMPONENT CONVENTION.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useId } from "react";

import { ActionButton, CloseButton } from "@/components/Button";
import { MessageStatus } from "@/libs/bridge";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";

export interface StatusFilterDialogProps {
  /** Svelte `bind:selectedStatus`. */
  selectedStatus?: MessageStatus | null;
  onSelectedStatusChange?: (status: MessageStatus | null) => void;
  /** Svelte `bind:menuOpen`. */
  menuOpen?: boolean;
  onMenuOpenChange?: (open: boolean) => void;
}

export default function StatusFilterDialog({
  selectedStatus = null,
  onSelectedStatusChange,
  menuOpen = false,
  onMenuOpenChange,
}: StatusFilterDialogProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe id replacing `crypto.randomUUID()` at script init.
  const dialogId = `dialog-${useId()}`;

  const closeMenu = () => {
    onMenuOpenChange?.(false);
  };

  const options = [
    { value: null, label: t("transactions.filter.all") },
    { value: MessageStatus.NEW, label: t("transactions.filter.processing") },
    { value: MessageStatus.RETRIABLE, label: t("transactions.filter.retry") },
    { value: MessageStatus.DONE, label: t("transactions.filter.claimed") },
    { value: MessageStatus.FAILED, label: t("transactions.filter.failed") },
    { value: MessageStatus.RECALLED, label: t("transactions.filter.released") },
  ];

  const select = (option: (typeof options)[0]) => {
    onSelectedStatusChange?.(option.value);
  };

  return (
    <dialog
      id={dialogId}
      className={cn("modal modal-bottom", { "modal-open": menuOpen })}
    >
      <div className="modal-box relative w-full bg-neutral-background !p-0">
        <div className="w-full pt-[35px] px-[24px]">
          <CloseButton onClick={closeMenu} />
          <h3 className="font-bold">{t("transactions.filter.title")}</h3>
        </div>
        <div className="h-sep my-[20px]" />
        <div className="w-full px-[24px] text-left">
          <h3 className="font-bold text-left">{t("common.status")}</h3>
          <div className="flex flex-wrap justify-center gap-[9px] mt-[16px]">
            {options.map((option) => (
              <ActionButton
                key={String(option.value)}
                priority={
                  option.value === selectedStatus ? "primary" : "secondary"
                }
                className="!max-h-[36px] btn-sm !px-[20px] !py-[8px]"
                onClick={() => select(option)}
                onKeyDown={() => select(option)}
              >
                {option.label}
              </ActionButton>
            ))}
          </div>
        </div>
        <div className="h-sep mt-[20px] mb-0" />
        <div className="w-full px-[24px] my-[20px]">
          <ActionButton priority="primary" onClick={closeMenu}>
            {t("common.see_results")}
          </ActionButton>
        </div>
      </div>
      <button className="overlay-backdrop" onClick={closeMenu} />
    </dialog>
  );
}
