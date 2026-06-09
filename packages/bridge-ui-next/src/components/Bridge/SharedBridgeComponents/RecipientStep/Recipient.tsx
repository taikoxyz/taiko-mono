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
  recipientAddress,
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
export interface RecipientHandle {
  clearRecipient: () => void;
}

export interface RecipientProps {
  small?: boolean;
  disabled?: boolean;
}

const Recipient = forwardRef<RecipientHandle, RecipientProps>(
  function Recipient({ small = false, disabled = false }, ref) {
    const { t } = useTranslation();

    const dialogId = `dialog-${useId()}`;

    const addressInputRef = useRef<AddressInputHandle>(null);

    const [modalOpen, setModalOpen] = useState(false);
    const [invalidRecipient, setInvalidRecipient] = useState(false);
    const [invalidDestOwner, setInvalidDestOwner] = useState(false);
    const prevRecipientAddressRef = useRef<Maybe<Address>>(null);

    const [recipientIsSmartContract, setRecipientIsSmartContract] =
      useState(false);

    // Stores.
    const $recipientAddress = useBridgeState(recipientAddress);
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
          recipientAddress.setState(() => null, true); // update state
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
      // Revert change of recipient address
      recipientAddress.setState(
        () => prevRecipientAddressRef.current ?? null,
        true,
      );
      destOwnerAddress.setState(
        () =>
          recipientIsSmartContract
            ? (account.getState()?.address ?? null)
            : null,
        true,
      );
      removeEscKeyListener();
      closeModal();
    }

    // $: modalOpenChange(modalOpen)
    useEffect(() => {
      if (modalOpen) {
        // Save it in case we want to cancel
        prevRecipientAddressRef.current = recipientAddress.getState();
      }
    }, [modalOpen]);

    function onRecipientValidation(detail: {
      isValidEthereumAddress: boolean;
      addr: Address | string;
    }) {
      const { isValidEthereumAddress, addr } = detail;

      if (isValidEthereumAddress) {
        validateRecipient(addr as Address);
      } else {
        setInvalidRecipient(true);
      }
    }

    const validateRecipient = async (addr: Address) => {
      recipientAddress.setState(() => addr, true);
      setInvalidRecipient(false);
      const dest = destNetwork.getState();
      if (dest?.id && (await isSmartContract(addr, dest.id))) {
        setRecipientIsSmartContract(true);
      } else {
        setRecipientIsSmartContract(false);
      }
    };

    function onDestOwnerValidation(detail: {
      isValidEthereumAddress: boolean;
      addr: Address | string;
    }) {
      const { isValidEthereumAddress, addr } = detail;
      if (isValidEthereumAddress) {
        validateDestOwner(addr as Address);
      } else {
        setInvalidDestOwner(true);
      }
    }

    const validateDestOwner = async (addr: Address) => {
      destOwnerAddress.setState(() => addr, true);
      setInvalidDestOwner(false);
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

    // $: ethereumAddressBinding = $recipientAddress || undefined;
    const ethereumAddressBinding = $recipientAddress || undefined;
    const destOwnerAddressBinding = $destOwnerAddress || undefined;

    // $: displayedRecipient = $recipientAddress || $account?.address;
    const displayedRecipient = $recipientAddress || $account?.address;

    return (
      <div className="Recipient f-col">
        {small ? (
          <div className="f-between-center">
            <span className="text-secondary-content">
              {t("recipient.title")}
            </span>
            {displayedRecipient ? (
              <>
                {shortenAddress(displayedRecipient, 8, 10)}
                {displayedRecipient !== $account?.address && (
                  <span className="text-primary-link">
                    | {t("common.customized")}
                  </span>
                )}
              </>
            ) : (
              t("recipient.placeholder")
            )}
          </div>
        ) : (
          <>
            <div className="f-between-center">
              <div className="flex space-x-2">
                <span className="body-small-bold text-primary-content">
                  {t("recipient.title")}
                </span>
                <Tooltip>
                  <h2>{t("recipient.tooltip_title")}</h2>
                  {t("recipient.tooltip")}
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
              {displayedRecipient ? (
                <>
                  {shortenAddress(displayedRecipient, 15, 13)}
                  {displayedRecipient !== $account?.address && (
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
                    {t("recipient.title")}
                  </h3>

                  <p className="body-regular text-secondary-content mb-3">
                    {t("recipient.description")}
                  </p>

                  <div className="relative my-[20px]">
                    <AddressInput
                      ref={addressInputRef}
                      ethereumAddress={ethereumAddressBinding}
                      onAddressValidation={onRecipientValidation}
                      onDialog
                      resettable
                    />
                  </div>

                  {recipientIsSmartContract && (
                    <>
                      <p className="body-regular text-secondary-content mb-3">
                        You are sending funds to a smart contract. Please
                        provide an alternate address that can manually claim the
                        funds if the relayer doesn&apos;t or you configured it
                        that way. Ensure this is an address you control, as you
                        cannot claim the funds as the smart contract directly.
                      </p>
                      <div className="relative my-[20px] space-y-4">
                        <AddressInput
                          ethereumAddress={destOwnerAddressBinding}
                          onAddressValidation={onDestOwnerValidation}
                          resettable
                          onDialog
                        />
                      </div>
                    </>
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
                        invalidRecipient ||
                        invalidDestOwner ||
                        !ethereumAddressBinding ||
                        (recipientIsSmartContract && !destOwnerAddressBinding)
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

export default Recipient;
