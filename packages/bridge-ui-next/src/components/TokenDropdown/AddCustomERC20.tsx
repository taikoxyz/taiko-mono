"use client";

import { readContract } from "@wagmi/core";
import { useEffect, useId, useMemo, useRef, useState } from "react";
import { type Address, formatUnits } from "viem";

import { erc20Abi } from "@/abi";
import { FlatAlert } from "@/components/Alert";
import AddressInput, {
  type AddressInputHandle,
  AddressInputState,
} from "@/components/Bridge/SharedBridgeComponents/AddressInput";
import { destNetwork } from "@/components/Bridge/state";
import { ActionButton, CloseButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import Erc20 from "@/components/Icon/ERC20";
import { Spinner } from "@/components/Spinner";
import { useTranslation } from "@/i18n/useTranslation";
import { tokenService } from "@/libs/storage/services";
import {
  detectContractType,
  type GetTokenInfo,
  type Token,
  TokenType,
} from "@/libs/token";
import { getTokenAddresses } from "@/libs/token/getTokenAddresses";
import { getTokenWithInfoFromAddress } from "@/libs/token/getTokenWithInfoFromAddress";
import { getLogger } from "@/libs/util/logger";
import { config } from "@/libs/wagmi";
import { account } from "@/stores/account";
import { connectedSourceChain } from "@/stores/network";
import { cn } from "@/lib/utils";

const log = getLogger("component:AddCustomERC20");

export interface AddCustomErc20Props {
  /** Controlled open state (Svelte `bind:modalOpen`). */
  modalOpen?: boolean;
  /** Write-back for the two-way bound `modalOpen`. */
  onModalOpenChange?: (open: boolean) => void;
  /** Controlled loading flag (Svelte `bind:loadingTokenDetails`). */
  loadingTokenDetails?: boolean;
  /** Write-back for the two-way bound `loadingTokenDetails`. */
  onLoadingTokenDetailsChange?: (loading: boolean) => void;
  /** Two-way bound custom token list (Svelte `bind:customTokens`). */
  customTokens?: Token[];
  /** Write-back for the two-way bound `customTokens`. */
  onCustomTokensChange?: (tokens: Token[]) => void;
  /** Svelte `dispatch('tokenRemoved', { token })` -> `onTokenRemoved({ token })`. */
  onTokenRemoved?: (detail: { token: Token }) => void;
}

export default function AddCustomErc20({
  modalOpen = false,
  onModalOpenChange,
  loadingTokenDetails: loadingTokenDetailsProp = false,
  onLoadingTokenDetailsChange,
  customTokens = [],
  onCustomTokensChange,
  onTokenRemoved,
}: AddCustomErc20Props) {
  const { t } = useTranslation();

  // Stable, SSR-safe per-instance dialog id (replaces Svelte `crypto.randomUUID()`).
  const dialogId = `dialog-${useId()}`;

  const addressInputRef = useRef<AddressInputHandle>(null);
  // Holds the latest `closeModal` so the always-on window keydown listener can
  // call it without the effect body lexically referencing a setter-calling
  // closure (keeps the listener attached for the component's lifetime, exactly
  // like the original `<svelte:window on:keydown>`).
  const closeModalRef = useRef<() => void>(() => {});

  // Local mutable state (Svelte `let`).
  const [tokenAddress, setTokenAddress] = useState<Address | string>("");
  const [customToken, setCustomToken] = useState<Token | null>(null);
  const [customTokenWithDetails, setCustomTokenWithDetails] =
    useState<Token | null>(null);
  const [isValidEthereumAddress, setIsValidEthereumAddress] = useState(false);
  const [state, setState] = useState<AddressInputState>(
    AddressInputState.DEFAULT,
  );
  const [loadingTokenDetails, setLoadingTokenDetailsState] = useState(
    loadingTokenDetailsProp,
  );

  // Keep the bound `loadingTokenDetails` in sync with the parent's write-back.
  const setLoadingTokenDetails = (loading: boolean) => {
    setLoadingTokenDetailsState(loading);
    onLoadingTokenDetailsChange?.(loading);
  };

  const resetForm = () => {
    setCustomToken(null);
    setCustomTokenWithDetails(null);
    setIsValidEthereumAddress(false);
    setState(AddressInputState.DEFAULT);
    if (addressInputRef.current) addressInputRef.current.clearAddress();
  };

  const addCustomErc20Token = async () => {
    if (customToken) {
      tokenService.storeToken(
        customToken,
        account.getState()?.address as Address,
      );
      onCustomTokensChange?.(
        tokenService.getTokens(account.getState()?.address as Address),
      );

      const srcChain = connectedSourceChain.getState();
      const destChain = destNetwork.getState();

      if (!srcChain || !destChain) return;

      // let's check if this token has already been bridged and store the info
      const tokenInfo = await getTokenAddresses({
        token: customToken,
        srcChainId: srcChain.id,
        destChainId: destChain.id,
      } as GetTokenInfo);

      if (tokenInfo && tokenInfo.bridged) {
        const { address: bridgedAddress, chainId: bridgedChainId } =
          tokenInfo.bridged;
        // only update the token if we actually have a bridged address
        if (bridgedAddress) {
          // Original mutated `customToken.addresses` in place; we build a new
          // token to satisfy React's immutability rules while preserving the
          // same persisted result.
          const updatedToken: Token = {
            ...customToken,
            addresses: {
              ...customToken.addresses,
              [bridgedChainId]: bridgedAddress as Address,
            },
          };
          setCustomToken(updatedToken);
          tokenService.updateToken(
            updatedToken,
            account.getState()?.address as Address,
          );
        }
      }
    }

    setTokenAddress("");
    setCustomTokenWithDetails(null);
    resetForm();
  };

  const closeModal = () => {
    onModalOpenChange?.(false);
    resetForm();
  };
  // Keep the always-on keydown listener pointed at the latest `closeModal`.
  // Assigned in an effect (after render) to satisfy React's "no ref writes
  // during render" rule.
  useEffect(() => {
    closeModalRef.current = closeModal;
  });

  const remove = (token: Token) => {
    onTokenRemoved?.({ token });
  };

  const onAddressChange = async (addr: Address) => {
    if (!addr) return;
    setLoadingTokenDetails(true);
    log('Fetching token details for address "%s"…', addr);

    let type: TokenType;
    try {
      type = await detectContractType(
        addr,
        connectedSourceChain.getState()?.id as number,
      );
    } catch (error) {
      log("Failed to detect contract type: ", error);
      setLoadingTokenDetails(false);
      setState(AddressInputState.NOT_ERC20);
      return;
    }

    if (type !== TokenType.ERC20) {
      setLoadingTokenDetails(false);
      setState(AddressInputState.NOT_ERC20);
      return;
    }

    const srcChain = connectedSourceChain.getState();
    if (!srcChain) return;
    try {
      const token = await getTokenWithInfoFromAddress({
        contractAddress: addr,
        srcChainId: srcChain.id,
      });
      if (!token) return;
      const balance = await readContract(config, {
        address: addr,
        abi: erc20Abi,
        functionName: "balanceOf",
        args: [account.getState()?.address as Address],
      });
      const withDetails = { ...token, balance } as Token;
      setCustomTokenWithDetails(withDetails);
      setCustomToken(withDetails);
    } catch (error) {
      setState(AddressInputState.INVALID);
      log("Failed to fetch token: ", error);
    }
    setLoadingTokenDetails(false);
  };

  const onAddressValidation = async (detail: {
    isValidEthereumAddress: boolean;
    addr: Address | string;
  }) => {
    const { isValidEthereumAddress: isValid, addr } = detail;
    setTokenAddress(addr);
    setIsValidEthereumAddress(isValid);
    if (isValid) {
      await onAddressChange(addr as Address);
    } else {
      setTokenAddress(addr);
    }
  };

  // $: formattedBalance = ...
  const formattedBalance = useMemo(
    () =>
      customTokenWithDetails?.balance && customTokenWithDetails?.decimals
        ? formatUnits(
            customTokenWithDetails.balance,
            customTokenWithDetails.decimals,
          )
        : 0,
    [customTokenWithDetails],
  );

  // $: disabled = state !== VALID || tokenAddress === '' || tokenAddress.length !== 42;
  const disabled = useMemo(
    () =>
      state !== AddressInputState.VALID ||
      tokenAddress === "" ||
      tokenAddress.length !== 42,
    [state, tokenAddress],
  );

  // <svelte:window on:keydown={closeModalIfKeyDown} />
  useEffect(() => {
    const closeModalIfKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        closeModalRef.current();
      }
    };
    window.addEventListener("keydown", closeModalIfKeyDown);
    return () => window.removeEventListener("keydown", closeModalIfKeyDown);
  }, []);

  const closeModalIfClickedOutside = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      closeModal();
    }
  };

  return (
    <dialog
      id={dialogId}
      className={cn(
        "modal modal-bottom md:modal-middle",
        modalOpen && "modal-open",
      )}
    >
      <div className="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-dialog-background">
        <CloseButton onClick={closeModal} />
        <h3 className="title-body-bold mb-7">
          {t("token_dropdown.custom_token.title")}
        </h3>

        <p className="body-regular text-secondary-content mb-3">
          {t("token_dropdown.custom_token.description")}
        </p>
        <div className="mt-4 mb-2 w-full">
          <AddressInput
            ref={addressInputRef}
            ethereumAddress={tokenAddress}
            onEthereumAddressChange={setTokenAddress}
            onAddressValidation={onAddressValidation}
            state={state}
            onStateChange={setState}
            onDialog
          />
          <div className="w-full flex items-center justify-between">
            {customTokenWithDetails ? (
              <>
                <span>
                  {t("common.name")}: {customTokenWithDetails.symbol}
                </span>
                <span>
                  {t("common.balance")}: {formattedBalance}
                </span>
              </>
            ) : state === AddressInputState.INVALID &&
              tokenAddress !== "" &&
              isValidEthereumAddress &&
              !loadingTokenDetails ? (
              <FlatAlert
                type="error"
                message={t("bridge.errors.custom_token.not_found.message")}
              />
            ) : loadingTokenDetails ? (
              <Spinner />
            ) : state === AddressInputState.DEFAULT ? (
              <FlatAlert
                type="info"
                message={t("token_dropdown.custom_token.default_message")}
              />
            ) : null}
          </div>
        </div>
        <div className="h-sep" />
        {customTokens.length > 0 ? (
          <div className="flex h-full w-full flex-col justify-between mt-6">
            <h3 className="title-body-bold mb-7">
              {t("token_dropdown.imported_tokens")}
            </h3>
            {customTokens.map((ct) => (
              <div
                key={ct.symbol}
                className="flex items-center justify-between"
              >
                <div className="flex items-center m-2 space-x-2">
                  <Erc20 />
                  <span>{ct.symbol}</span>
                </div>
                <button
                  className="btn btn-sm btn-ghost flex justify-center items-center"
                  onClick={() => remove(ct)}
                >
                  <Icon type="trash" fillClass="fill-primary-icon" size={24} />
                </button>
              </div>
            ))}
          </div>
        ) : (
          <span>{t("token_dropdown.no_imported_token")}</span>
        )}
        <div className="h-sep" />
        <ActionButton
          priority="primary"
          disabled={disabled}
          onClick={addCustomErc20Token}
          onPopup
        >
          {t("token_dropdown.custom_token.button")}
        </ActionButton>
      </div>
      {/* We catch key events above */}
      <div
        role="button"
        tabIndex={0}
        className="overlay-backdrop"
        onClick={closeModalIfClickedOutside}
      />
    </dialog>
  );
}
