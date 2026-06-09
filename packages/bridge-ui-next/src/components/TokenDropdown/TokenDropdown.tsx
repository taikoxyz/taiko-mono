"use client";

import { deepEqual } from "@wagmi/core";
import { useEffect, useId, useMemo, useState } from "react";
import type { Address } from "viem";
import { zeroAddress } from "viem";

import {
  computingBalance,
  destNetwork,
  errorComputingBalance,
  selectedToken,
  tokenBalance,
} from "@/components/Bridge/state";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import { Icon } from "@/components/Icon";
import Erc20 from "@/components/Icon/ERC20";
import { warningToast } from "@/components/NotificationToast";
import { OnAccount } from "@/components/OnAccount";
import { useTranslation } from "@/i18n/useTranslation";
import { tokenService } from "@/libs/storage/services";
import {
  ETHToken,
  fetchBalance as getTokenBalance,
  type NFT,
  type Token,
  TokenType,
} from "@/libs/token";
import { getTokenAddresses } from "@/libs/token/getTokenAddresses";
import { getLogger } from "@/libs/util/logger";
import { truncateString } from "@/libs/util/truncateString";
import { type Account, account } from "@/stores/account";
import { connectedSourceChain } from "@/stores/network";
import { cn } from "@/lib/utils";

import AddCustomErc20 from "./AddCustomERC20";
import DialogView from "./DialogView";
import DropdownView from "./DropdownView";
import { symbolToIconMap } from "./symbolToIconMap";
import { TabTypes } from "./types";

const log = getLogger("TokenDropdown");

export interface TokenDropdownProps {
  tokens?: Token[];
  /** Controlled selected token (Svelte `bind:value`). */
  value?: Maybe<Token | NFT>;
  /** Write-back for the two-way bound `value`. */
  onValueChange?: (value: Maybe<Token | NFT>) => void;
  onlyMintable?: boolean;
  disabled?: boolean;
  combined?: boolean;
  /** Maps Svelte's `$$props.class`. */
  className?: string;
  /** Svelte `dispatch('tokenSelected', { token })`. */
  onTokenSelected?: (detail: { token: Token }) => void;
  /** Forwarded `on:tokenRemoved` (re-dispatched from AddCustomErc20). */
  onTokenRemoved?: (detail: { token: Token }) => void;
}

export default function TokenDropdown({
  tokens = [],
  value: valueProp = null,
  onValueChange,
  onlyMintable = false,
  disabled = false,
  combined = false,
  className,
  onTokenSelected,
  onTokenRemoved,
}: TokenDropdownProps) {
  const { t } = useTranslation();

  // Stable, SSR-safe per-instance menu id (replaces Svelte `crypto.randomUUID()`).
  const id = `menu-${useId()}`;

  // `value` is controlled (Svelte `bind:value`) with an internal fallback so the
  // component can mutate it locally (e.g. on selection / removal) exactly like
  // the original `value = token`.
  const [internalValue, setInternalValue] =
    useState<Maybe<Token | NFT>>(valueProp);
  const value = valueProp ?? internalValue;
  const setValue = (next: Maybe<Token | NFT>) => {
    setInternalValue(next);
    onValueChange?.(next);
  };

  const [customTokenModalOpen, setCustomTokenModalOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [activeTab, setActiveTab] = useState<TabTypes>(TabTypes.TOKEN);
  const [customTokens, setCustomTokens] = useState<Token[]>(() =>
    tokenService.getTokens(account.getState()?.address as Address),
  );

  // This will control which view to render depending on the screensize.
  // Since markup will differ, and there is logic running when interacting
  // with this component, it makes more sense to not render the view that's
  // not being used, doing this with JS instead of CSS media queries.
  const isDesktopOrLarger = useDesktopOrLarger();

  const closeMenu = () => setMenuOpen(false);
  const openMenu = () => setMenuOpen(true);

  const updateBalance = async () => {
    const userAddress = account.getState()?.address;
    const srcChainId = connectedSourceChain.getState()?.id;
    const destChainId = destNetwork.getState()?.id;
    const token = value;
    if (!token || !srcChainId || !userAddress) return;
    computingBalance.setState(true);
    errorComputingBalance.setState(false);

    try {
      if (token.type === TokenType.ERC20) {
        tokenBalance.setState(
          await getTokenBalance({
            token,
            srcChainId,
            destChainId,
            userAddress,
          }),
        );
      } else if (token.type === TokenType.ETH) {
        tokenBalance.setState(
          await getTokenBalance({
            token: ETHToken,
            srcChainId,
            destChainId,
            userAddress,
          }),
        );
      } else {
        tokenBalance.setState(
          await getTokenBalance({
            token,
            srcChainId,
            destChainId,
            userAddress,
          }),
        );
      }
    } catch (err) {
      log("Error updating balance: ", err);
      // most likely we have a custom token that is not bridged yet
      errorComputingBalance.setState(true);
      // clearAmount();
    }
    computingBalance.setState(false);
  };

  const selectToken = async (token: Token) => {
    onTokenSelected?.({ token });
    const srcChain = connectedSourceChain.getState();
    const destChain = destNetwork.getState();
    computingBalance.setState(true);
    closeMenu();
    log("selected token", token);
    if (token === value) {
      log("same token, nothing to do");
      // same token, nothing to do
      computingBalance.setState(false);
      return;
    }

    // In order to select a token, we only need the source chain to be selected,
    if (!srcChain) {
      warningToast({ title: t("messages.network.required") });
      computingBalance.setState(false);
      return;
    }
    if (!destChain || !destChain.id) {
      warningToast({ title: t("messages.network.required_dest") });
      computingBalance.setState(false);
      return;
    }
    try {
      const tokenInfo = await getTokenAddresses({
        token,
        srcChainId: srcChain.id,
        destChainId: destChain.id,
      });
      if (!tokenInfo) {
        computingBalance.setState(false);
      } else {
        if (
          tokenInfo.bridged?.chainId &&
          tokenInfo.bridged?.address &&
          tokenInfo.bridged?.address !== zeroAddress
        ) {
          token.addresses[tokenInfo.bridged.chainId] =
            tokenInfo.bridged.address;
          tokenService.updateToken(
            token,
            account.getState()?.address as Address,
          );
        }
      }
    } catch (error) {
      computingBalance.setState(false);
      console.error(error);
    }
    setValue(token);
    await updateBalance();
    computingBalance.setState(false);
  };

  const handleCustomTokenModal = () => {
    closeMenu();
    setCustomTokenModalOpen(true);
  };

  const handleTokenRemoved = (detail: { token: Token }) => {
    const token = detail.token;

    // if the selected token is the one that was removed by the user, remove it
    if (deepEqual(token, value)) {
      setValue(ETHToken);
    }
    const address = account.getState()?.address;
    tokenService.removeToken(token, address as Address);
    setCustomTokens(tokenService.getTokens(address as Address));
  };

  const reset = () => {
    const srcChain = connectedSourceChain.getState();
    const destChain = destNetwork.getState();
    const user = account.getState()?.address;
    selectedToken.setState(ETHToken);
    if (!srcChain || !destChain || !user) return;
    computingBalance.setState(true);
    const next = tokens[0];
    setValue(next);
    selectedToken.setState(next);
    computingBalance.setState(false);
  };

  const onAccountChange = (
    newAccount: Account | undefined,
    prevAccount?: Account,
  ) => {
    if (
      newAccount?.chainId === prevAccount?.chainId ||
      !newAccount ||
      !prevAccount
    )
      reset();
  };

  // $: textClass = disabled ? 'text-secondary-content' : 'font-bold ';
  const textClass = useMemo(
    () => (disabled ? "text-secondary-content" : "font-bold "),
    [disabled],
  );

  // onMount -> reset(); onDestroy -> closeMenu()
  // `reset` is deferred to a microtask (the original `reset` was async and
  // awaited `tick()`); this also avoids a synchronous setState inside the mount
  // effect.
  useEffect(() => {
    queueMicrotask(() => reset());
    return () => closeMenu();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const ValueIcon = value ? symbolToIconMap[value.symbol] : null;

  return (
    <>
      <div className={cn("relative h-full", className)}>
        <button
          disabled={disabled}
          aria-haspopup="listbox"
          aria-controls={id}
          aria-expanded={menuOpen}
          className={cn(
            `f-between-center w-full h-full px-[20px] py-[14px] input-box bg-neutral-background border-0 shadow-none outline-none`,
            combined ? "!rounded-l-[0px] !rounded-r-[10px]" : "!rounded-[10px]",
          )}
          onClick={(e) => {
            e.stopPropagation();
            openMenu();
          }}
        >
          <div className="space-x-2">
            {!value || disabled ? (
              <span className="title-subsection-bold text-base text-secondary-content">
                {t("token_dropdown.label")}
              </span>
            ) : value ? (
              <div className="flex f-space-between space-x-2 items-center text-secondary-content">
                {/* Only match icons to configured tokens */}
                {ValueIcon && !value.imported ? (
                  <i role="img" aria-label={value.name}>
                    <ValueIcon size={20} />
                  </i>
                ) : value.logoURI ? (
                  <img
                    src={value.logoURI}
                    alt={value.name}
                    className="w-[20px] h-[20px] rounded-[50%]"
                  />
                ) : (
                  <i role="img" aria-label={value.symbol}>
                    <Erc20 size={20} />
                  </i>
                )}
                <span className={textClass}>
                  {truncateString(value.symbol, 6)}
                </span>
              </div>
            ) : null}
          </div>
          {!disabled ? <Icon type="chevron-down" size={10} /> : null}
        </button>
        {isDesktopOrLarger ? (
          <DropdownView
            id={id}
            menuOpen={menuOpen}
            onMenuOpenChange={setMenuOpen}
            onlyMintable={onlyMintable}
            tokens={tokens}
            customTokens={customTokens}
            onCustomTokensChange={setCustomTokens}
            value={value}
            selectToken={selectToken}
            closeMenu={closeMenu}
            activeTab={activeTab}
            onActiveTabChange={setActiveTab}
            onTokenRemoved={handleTokenRemoved}
            onOpenCustomTokenModal={handleCustomTokenModal}
          />
        ) : (
          <DialogView
            id={id}
            menuOpen={menuOpen}
            onMenuOpenChange={setMenuOpen}
            onlyMintable={onlyMintable}
            tokens={tokens}
            customTokens={customTokens}
            onCustomTokensChange={setCustomTokens}
            value={value}
            selectToken={selectToken}
            closeMenu={closeMenu}
            activeTab={activeTab}
            onActiveTabChange={setActiveTab}
            onTokenRemoved={handleTokenRemoved}
            onOpenCustomTokenModal={handleCustomTokenModal}
          />
        )}
      </div>

      <div data-modal-uuid={id} />

      <OnAccount change={onAccountChange} />

      <AddCustomErc20
        modalOpen={customTokenModalOpen}
        onModalOpenChange={setCustomTokenModalOpen}
        customTokens={customTokens}
        onCustomTokensChange={setCustomTokens}
        onTokenRemoved={onTokenRemoved}
      />
    </>
  );
}
