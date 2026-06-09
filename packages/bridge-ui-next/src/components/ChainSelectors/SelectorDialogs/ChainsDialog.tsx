"use client";

import { useId, useRef, useState } from "react";
import type { Chain } from "viem";

import { chainConfig } from "@/config/generated/chainConfig";
import { destNetwork, useBridgeState } from "@/components/Bridge/state";
import { CloseButton } from "@/components/Button";
import { ActionButton } from "@/components/Button";
import { chains } from "@/libs/chain";
import type { ChainConfigMap } from "@/libs/chain";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import { useConnectedSourceChain } from "@/stores/network";
import { useTranslation } from "@/i18n/useTranslation";

import type { ChainSelectChangeDetail } from "./ChainsDropdown";

// The generated chainConfig is typed loosely (Record<string, unknown>); narrow it
// to read `.icon` / `.type`, matching the original `$chainConfig` usage.
const config = chainConfig as unknown as ChainConfigMap;

export interface ChainsDialogProps {
  /** Svelte `bind:isOpen` -> controlled `isOpen` + `onIsOpenChange`. */
  isOpen?: boolean;
  onIsOpenChange?: (isOpen: boolean) => void;
  /** Svelte `bind:value` (or one-way `value`) -> controlled `value`. */
  value?: Maybe<Chain>;
  switchWallet?: boolean;
  /** Svelte `dispatch('change', detail)` -> `onChange(detail)`. */
  onChange?: (detail: ChainSelectChangeDetail) => void;
}

export default function ChainsDialog({
  isOpen = false,
  onIsOpenChange,
  value = null,
  switchWallet = false,
  onChange,
}: ChainsDialogProps) {
  const { t } = useTranslation();
  const $connectedSourceChain = useConnectedSourceChain();
  const $destNetwork = useBridgeState(destNetwork);

  // const dialogId = `dialog-${crypto.randomUUID()}`; — stable, SSR-safe id.
  const dialogId = `dialog-${useId()}`;

  // let modalOpen = false; — internal open state.
  // Mirrors the svelte reactive `$: if (isOpen) modalOpen = true; else closeModal()`:
  // `modalOpen` follows `isOpen` transitions, but can also be closed locally
  // (CloseButton / confirm) WITHOUT changing the parent's `isOpen`. We adjust this
  // state during render by tracking the previously-seen `isOpen` (the React-
  // sanctioned "store info from previous renders" pattern), avoiding a setState-in-
  // effect cascade.
  const [modalOpen, setModalOpen] = useState(false);
  const [prevIsOpen, setPrevIsOpen] = useState(isOpen);

  // const selectChain = (selectedChain) => (value = selectedChain);
  // The dialog locally mutates `value`; mirror with internal state seeded from the
  // prop, resetting whenever the incoming prop changes (svelte reassigns the prop).
  const [selectedValue, setSelectedValue] = useState<Maybe<Chain>>(value);
  const [prevValue, setPrevValue] = useState<Maybe<Chain>>(value);
  // let selectedChainId: number | undefined; (radio group binding)
  const [selectedChainId, setSelectedChainId] = useState<number | undefined>(
    undefined,
  );

  if (prevIsOpen !== isOpen) {
    // $: if (isOpen) { modalOpen = true } else { closeModal() }
    setPrevIsOpen(isOpen);
    setModalOpen(isOpen);
  }

  if (prevValue !== value) {
    setPrevValue(value);
    setSelectedValue(value);
  }

  // $: isDestination = !switchWallet;
  const isDestination = !switchWallet;

  // $: title = isDestination ? to_placeholder : from_placeholder;
  const title = isDestination
    ? t("chain_selector.to_placeholder")
    : t("chain_selector.from_placeholder");

  const selectChain = (selectedChain: Chain) => setSelectedValue(selectedChain);
  const closeModal = () => setModalOpen(false);

  const onConfirmClick = () => {
    onChange?.({ chain: selectedValue as Chain, switchWallet });
    closeModal();
  };

  // use:closeOnEscapeOrOutsideClick={{ enabled: isOpen, callback: () => (isOpen = false), uuid: dialogId }}
  const dialogRef = useRef<HTMLDialogElement>(null);
  useCloseOnEscapeOrOutsideClick(dialogRef, {
    enabled: isOpen,
    callback: () => onIsOpenChange?.(false),
    uuid: dialogId,
  });

  return (
    <dialog
      ref={dialogRef}
      id={dialogId}
      className={`modal modal-bottom${modalOpen ? " modal-open" : ""}`}
    >
      <div className="modal-box relative px-[24px] py-[35px] rounded-0 bg-neutral-background">
        <CloseButton onClick={closeModal} />
        <div className="f-col w-full space-y-[30px]">
          <h3 className="title-body-bold">{title}</h3>
        </div>
        <div className="h-sep !my-[20px]" />
        <ul role="listbox" className="text-white text-sm w-full">
          {chains.map((chain) => {
            const disabled = !isDestination
              ? chain.id === $connectedSourceChain?.id
              : chain.id === $destNetwork?.id ||
                chain.id === $connectedSourceChain?.id;
            const icon = config[Number(chain.id)]?.icon || "Unknown Chain";
            return (
              <li
                key={chain.id}
                role="menuitem"
                tabIndex={0}
                className={`h-[64px] rounded-[10px] text-primary-content
          ${disabled ? "opacity-50" : "hover:bg-primary-brand hover:text-white"}`}
                aria-disabled={disabled}
              >
                <label
                  className={`f-row items-center w-full h-full p-[16px] ${disabled ? "cursor-not-allowed" : "cursor-pointer"}`}
                >
                  <input
                    type="radio"
                    name="nft-radio"
                    checked={selectedChainId === chain.id}
                    value={chain.id}
                    className="flex-none mr-[8px] radio radio-secondary"
                    disabled={disabled}
                    onChange={() => {
                      setSelectedChainId(chain.id);
                      selectChain(chain);
                    }}
                  />
                  <div className="f-row justify-between w-full">
                    <div className="f-items-center gap-2">
                      <i role="img" aria-label={chain.name}>
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img
                          src={icon}
                          alt="chain-logo"
                          className="rounded-full w-7 h-7"
                        />
                      </i>
                      <span className="body-bold">{chain.name}</span>
                    </div>

                    <span className="f-items-center body-regular">
                      {config[chain.id].type}
                    </span>
                  </div>
                </label>
              </li>
            );
          })}
        </ul>
        <div className="h-sep !my-[20px]" />
        <ActionButton priority="primary" onClick={() => onConfirmClick()}>
          {t("common.confirm")}
        </ActionButton>
      </div>

      <button className="overlay-backdrop" data-modal-uuid={dialogId} />
    </dialog>
  );
}
