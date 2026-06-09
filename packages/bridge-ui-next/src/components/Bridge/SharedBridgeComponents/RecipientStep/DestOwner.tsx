"use client";

import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useRef,
  useState,
} from "react";
import type { Address } from "viem";

import {
  destNetwork,
  destOwnerAddress,
  useBridgeState,
} from "@/components/Bridge/state";
import { ActionButton, CloseButton } from "@/components/Button";
import { Tooltip } from "@/components/Tooltip";
import { isSmartContract } from "@/libs/util/isSmartContract";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { account, useAccount } from "@/stores/account";
import { cn } from "@/lib/utils";
import { useTranslation } from "@/i18n/useTranslation";

import AddressInput, {
  type AddressInputHandle,
} from "../AddressInput/AddressInput";

/** Public API (Svelte `export const clearRecipient`). */
export interface DestOwnerHandle {
  clearRecipient: () => void;
}

export interface DestOwnerProps {
  small?: boolean;
  disabled?: boolean;
}

const DestOwner = forwardRef<DestOwnerHandle, DestOwnerProps>(
  function DestOwner({ small = false, disabled = false }, ref) {
    const { t } = useTranslation();

    const dialogId = `dialog-${useId()}`;
    const addressInputRef = useRef<AddressInputHandle>(null);

    const [modalOpen, setModalOpen] = useState(false);
    const [invalidAddress, setInvalidAddress] = useState(false);
    const prevDestOwnerAddressRef = useRef<Maybe<Address>>(null);

    const [destOwnerIsSmartContract, setDestOwnerIsSmartContract] =
      useState(false);

    // `ethereumAddressBinding` is a constant `undefined` in the source (`$: ethereumAddressBinding = undefined`).
    const [ethereumAddressBinding, setEthereumAddressBinding] = useState<
      Address | string | undefined
    >(undefined);

    const $destOwnerAddress = useBridgeState(destOwnerAddress);
    const $account = useAccount((s) => s);

    const escKeyListenerRef = useRef<((event: KeyboardEvent) => void) | null>(
      null,
    );

    // Public API.
    useImperativeHandle(
      ref,
      () => ({
        clearRecipient: () => {
          if (addressInputRef.current) addressInputRef.current.clearAddress(); // update UI
          destOwnerAddress.setState(() => null, true); // update state
        },
      }),
      [],
    );

    function closeModal() {
      setModalOpen(false);
    }

    function openModal() {
      setModalOpen(true);
      addressInputRef.current?.focus();
      addEscKeyListener();
    }

    function cancelModal() {
      // Revert change of destOwner address
      destOwnerAddress.setState(
        () => prevDestOwnerAddressRef.current ?? null,
        true,
      );
      removeEscKeyListener();
      closeModal();
    }

    // $: modalOpenChange(modalOpen)
    useEffect(() => {
      if (modalOpen) {
        // Save it in case we want to cancel
        prevDestOwnerAddressRef.current = destOwnerAddress.getState();
      }
    }, [modalOpen]);

    async function onAddressValidation(detail: {
      isValidEthereumAddress: boolean;
      addr: Address | string;
    }) {
      const { isValidEthereumAddress, addr } = detail;
      if (isValidEthereumAddress) {
        setInvalidAddress(false);
        const dest = destNetwork.getState();
        if (dest?.id && (await isSmartContract(addr as Address, dest.id))) {
          setDestOwnerIsSmartContract(true);
        } else {
          setDestOwnerIsSmartContract(false);
          destOwnerAddress.setState(() => addr as Address, true);
        }
      } else {
        setInvalidAddress(true);
      }
    }

    // on:clearInput={resetAddress}
    const resetAddress = () => {
      destOwnerAddress.setState(
        () => account.getState()?.address ?? null,
        true,
      );
      setEthereumAddressBinding(undefined);
      setDestOwnerIsSmartContract(false);
    };

    const addEscKeyListener = () => {
      const listener = (event: KeyboardEvent) => {
        if (event.key === "Escape") {
          closeModal();
        }
      };
      escKeyListenerRef.current = listener;
      window.addEventListener("keydown", listener);
    };

    const removeEscKeyListener = () => {
      if (escKeyListenerRef.current) {
        window.removeEventListener("keydown", escKeyListenerRef.current);
      }
    };

    useEffect(() => {
      return () => removeEscKeyListener();
    }, []);

    // $: displayedDestOwner = $destOwnerAddress || $account?.address;
    const displayedDestOwner = $destOwnerAddress || $account?.address;

    return (
      <div className="Recipient f-col">
        {small ? (
          <div className="f-between-center">
            <span className="text-secondary-content">
              {t("destOwner.title")}
            </span>
            {displayedDestOwner ? (
              <>
                {shortenAddress(displayedDestOwner, 8, 10)}
                {displayedDestOwner !== $account?.address && (
                  <span className="text-primary-link">
                    | {t("common.customized")}
                  </span>
                )}
              </>
            ) : (
              t("destOwner.placeholder")
            )}
          </div>
        ) : (
          <>
            <div className="f-between-center">
              <div className="flex space-x-2">
                <span className="body-small-bold text-primary-content">
                  {t("destOwner.title")}
                </span>
                <Tooltip>
                  <h2>{t("destOwner.tooltip_title")}</h2>
                  {t("destOwner.tooltip")}
                </Tooltip>
              </div>
              {!disabled && (
                <button
                  className="link"
                  onClick={openModal}
                  onFocus={openModal}
                >
                  {t("common.edit")}
                </button>
              )}
            </div>

            <span className="body-small-regular text-secondary-content mt-[4px]">
              {displayedDestOwner ? (
                <>
                  {shortenAddress(displayedDestOwner, 15, 13)}
                  {displayedDestOwner !== $account?.address && (
                    <span className="text-primary-link">
                      | {t("common.customized")}
                    </span>
                  )}
                </>
              ) : (
                t("recipient.placeholder")
              )}
            </span>

            <dialog
              id={dialogId}
              className={cn("modal", modalOpen && "modal-open")}
            >
              <div className="modal-box relative px-6 md:rounded-[20px] bg-neutral-background">
                <CloseButton onClick={cancelModal} />

                <div className="w-full">
                  <h3 className="title-body-bold mb-7">
                    {t("destOwner.title")}
                  </h3>

                  <p className="body-regular text-secondary-content mb-3">
                    {t("destOwner.description")}
                  </p>

                  <div className="relative my-[20px]">
                    <AddressInput
                      ref={addressInputRef}
                      ethereumAddress={ethereumAddressBinding}
                      onEthereumAddressChange={setEthereumAddressBinding}
                      onAddressValidation={onAddressValidation}
                      onClearInput={resetAddress}
                      onDialog
                      resettable
                    />
                  </div>

                  {destOwnerIsSmartContract && (
                    <p className="body-regular text-secondary-content mb-3">
                      You cannot set a smart contract as destination owner.
                    </p>
                  )}

                  <div className="grid grid-cols-2 gap-[20px]">
                    <ActionButton
                      onClick={cancelModal}
                      priority="secondary"
                      onPopup
                    >
                      <span className="body-bold">{t("common.cancel")}</span>
                    </ActionButton>
                    <ActionButton
                      priority="primary"
                      disabled={
                        invalidAddress ||
                        !ethereumAddressBinding ||
                        destOwnerIsSmartContract
                      }
                      onClick={closeModal}
                      onPopup
                    >
                      <span className="body-bold">{t("common.confirm")}</span>
                    </ActionButton>
                  </div>
                </div>
              </div>
            </dialog>
          </>
        )}
      </div>
    );
  },
);

export default DestOwner;
