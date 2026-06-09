"use client";

// React port of
// components/Transactions/Filter/StatusFilterDropdown.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let selectedStatus = null` (two-way bound) -> controlled
//     `selectedStatus` prop + `onSelectedStatusChange`.
//   - internal `flipped` / `menuOpen` -> useState; `uuid` -> SSR-safe `useId()`.
//   - `IconFlipper` `bind:flipped` -> `flipped` + `onFlippedChange`.
//     `bind:this={iconFlipperComponent}` was declared-but-unused in the original
//     and is dropped.
//   - `use:closeOnEscapeOrOutsideClick={{...}}` -> `useCloseOnEscapeOrOutsideClick`
//     hook bound to the `<ul>` ref (the action's `node`).
//   - Reactive `$: menuClasses = classNames(...)` -> derived inline via classNames.
//   - `await tick(); closeMenu()` -> set status then close (order preserved; the
//     React state update is already scheduled before closeMenu runs).
//   - `on:click|stopPropagation` -> `onClick` with `e.stopPropagation()`.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useId, useRef, useState } from "react";

import IconFlipper from "@/components/Icon/IconFlipper";
import { MessageStatus } from "@/libs/bridge";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import { classNames } from "@/libs/util/classNames";
import { useTranslation } from "@/i18n/useTranslation";

export interface StatusFilterDropdownProps {
  /** Svelte `bind:selectedStatus`. */
  selectedStatus?: MessageStatus | null;
  onSelectedStatusChange?: (status: MessageStatus | null) => void;
}

export default function StatusFilterDropdown({
  selectedStatus = null,
  onSelectedStatusChange,
}: StatusFilterDropdownProps) {
  const { t } = useTranslation();

  const [flipped, setFlipped] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  // Stable, SSR-safe id replacing `crypto.randomUUID()` at script init.
  const uuid = `dropdown-${useId()}`;

  const listRef = useRef<HTMLUListElement>(null);

  const closeMenu = () => {
    setMenuOpen(false);
    setFlipped(false);
  };

  const options = [
    { value: null, label: t("transactions.filter.all") },
    { value: MessageStatus.NEW, label: t("transactions.filter.processing") },
    { value: MessageStatus.RETRIABLE, label: t("transactions.filter.retry") },
    { value: MessageStatus.DONE, label: t("transactions.filter.claimed") },
    { value: MessageStatus.FAILED, label: t("transactions.filter.failed") },
    { value: MessageStatus.RECALLED, label: t("transactions.filter.released") },
  ];

  const toggleMenu = () => {
    setMenuOpen((v) => !v);
    setFlipped((v) => !v);
  };

  const select = (option: (typeof options)[0]) => {
    onSelectedStatusChange?.(option.value);
    closeMenu();
  };

  useCloseOnEscapeOrOutsideClick(listRef, {
    enabled: menuOpen,
    callback: closeMenu,
    uuid,
  });

  const menuClasses = classNames(
    "menu absolute right-0 w-[210px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10 box-shadow-small",
    menuOpen ? "visible opacity-100" : "invisible opacity-0",
  );

  return (
    <div className="relative">
      <button
        aria-haspopup="listbox"
        aria-expanded={menuOpen}
        className="f-between-center w-[210px] min-h-[36px] max-h-[36px] px-6 bg-neutral border-0 shadow-none outline-none rounded-[6px]"
        onClick={(e) => {
          e.stopPropagation();
          toggleMenu();
        }}
      >
        <span className="text-primary-content font-bold">
          {selectedStatus !== null
            ? options.find((option) => option.value === selectedStatus)?.label
            : t("transactions.filter.all")}
        </span>
        <IconFlipper
          flipped={flipped}
          onFlippedChange={setFlipped}
          iconType1="chevron-left"
          iconType2="chevron-down"
          selectedDefault="chevron-left"
          size={15}
          noEvent
        />
      </button>
      {menuOpen && (
        <ul id={uuid} role="listbox" className={menuClasses} ref={listRef}>
          {options.map((option) => (
            <li
              key={String(option.value)}
              role="option"
              aria-selected={option.value === selectedStatus}
              tabIndex={0}
              className="flex items-center h-[56px] px-3 cursor-pointer rounded-[6px]"
              onClick={() => select(option)}
              onKeyDown={() => select(option)}
            >
              <span className="flex w-full h-[56px] text-primary-content font-bold">
                {option.label}
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
