"use client";

import { deepEqual } from "@wagmi/core";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";
import type { Address } from "viem";

import { DialogTabs } from "@/components/DialogTabs";
import { Icon } from "@/components/Icon";
import Erc20 from "@/components/Icon/ERC20";
import InputBox, { type InputBoxHandle } from "@/components/InputBox/InputBox";
import { OnAccount } from "@/components/OnAccount";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import { tokenService } from "@/libs/storage/services";
import type { NFT, Token } from "@/libs/token";
import { classNames } from "@/libs/util/classNames";
import { noop } from "@/libs/util/noop";
import { truncateString } from "@/libs/util/truncateString";
import { account } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

import AddCustomErc20 from "./AddCustomERC20";
import { symbolToIconMap } from "./symbolToIconMap";
import { TabTypes, TokenTabs } from "./types";

export interface DropdownViewProps {
  id: string;
  /** Controlled open state (Svelte `bind:menuOpen`). */
  menuOpen?: boolean;
  /** Write-back for the two-way bound `menuOpen`. */
  onMenuOpenChange?: (open: boolean) => void;
  closeMenu?: () => void;
  tokens?: Token[];
  /** Two-way bound custom token list (Svelte `bind:customTokens`). */
  customTokens?: Token[];
  /** Write-back for the two-way bound `customTokens`. */
  onCustomTokensChange?: (tokens: Token[]) => void;
  value?: Maybe<Token | NFT>;
  selectToken?: (token: Token) => void;
  onlyMintable?: boolean;
  /** Controlled active tab (Svelte `bind:activeTab`). */
  activeTab?: TabTypes;
  /** Write-back for the two-way bound `activeTab`. */
  onActiveTabChange?: (tab: TabTypes) => void;
  /** Svelte `dispatch('tokenRemoved', { token })`. */
  onTokenRemoved?: (detail: { token: Token }) => void;
  /** Svelte `dispatch('openCustomTokenModal')`. */
  onOpenCustomTokenModal?: () => void;
}

export default function DropdownView({
  id,
  menuOpen = false,
  // `onMenuOpenChange` is part of the shared view API (used by DialogView) but
  // the desktop dropdown never writes back menu state directly, mirroring the
  // original component. Kept in the props type, intentionally unused here.
  closeMenu = noop,
  tokens = [],
  customTokens = [],
  onCustomTokensChange,
  value = null,
  selectToken = noop,
  onlyMintable = false,
  activeTab = TabTypes.TOKEN,
  onActiveTabChange,
  onTokenRemoved,
  onOpenCustomTokenModal,
}: DropdownViewProps) {
  const { t } = useTranslation();

  const containerRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<InputBoxHandle>(null);

  const [enteredTokenName, setEnteredTokenName] = useState("");
  // `addArc20ModalOpen` in the original is local state never toggled true here
  // (the parent owns the real custom-token modal). Preserved for parity.
  const [addArc20ModalOpen, setAddArc20ModalOpen] = useState(false);

  const handleCloseMenu = () => {
    setEnteredTokenName("");
    closeMenu();
  };

  const getTokenKeydownHandler = (token: Token) => {
    return (event: ReactKeyboardEvent) => {
      if (event.key === "Enter") {
        selectToken(token);
      }
    };
  };

  const showAddERC20 = () => onOpenCustomTokenModal?.();

  const onAccountChange = () => {
    if (account.getState()?.address) {
      onCustomTokensChange?.(
        tokenService.getTokens(account.getState()?.address as Address),
      );
    }
  };

  const handleTabChange = (detail: { tabId: string }) => {
    onActiveTabChange?.(detail.tabId as TabTypes);
  };

  const searchToken = (event: React.FormEvent<HTMLInputElement>) => {
    setEnteredTokenName((event.target as HTMLInputElement).value);
  };

  const removeToken = (token: Token) => {
    onTokenRemoved?.({ token });
  };

  // $: if (enteredTokenName !== '') { filter } else { passthrough }
  const filteredTokens = useMemo(() => {
    if (enteredTokenName !== "") {
      return tokens.filter(
        (token) =>
          token.name.toLowerCase().includes(enteredTokenName.toLowerCase()) ||
          token.symbol.toLowerCase().includes(enteredTokenName.toLowerCase()),
      );
    }
    return tokens;
  }, [enteredTokenName, tokens]);

  const filteredCustomTokens = useMemo(() => {
    if (enteredTokenName !== "") {
      return customTokens.filter(
        (token) =>
          token.name.toLowerCase().includes(enteredTokenName.toLowerCase()) ||
          token.symbol.includes(enteredTokenName.toLowerCase()),
      );
    }
    return customTokens;
  }, [enteredTokenName, customTokens]);

  // $: menuClasses = classNames(...)
  const menuClasses = classNames(
    "menu absolute right-0 w-[244px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10  box-shadow-small",
    menuOpen ? "visible opacity-100" : "invisible opacity-0",
  );

  // onMount/onDestroy tokenService subscribe/unsubscribe
  useEffect(() => {
    const handleStorageChange = (newTokens: Token[]) => {
      onCustomTokensChange?.(newTokens);
    };
    tokenService.subscribeToChanges(handleStorageChange);
    return () => tokenService.unsubscribeFromChanges(handleStorageChange);
  }, [onCustomTokensChange]);

  useCloseOnEscapeOrOutsideClick(containerRef, {
    enabled: menuOpen,
    callback: handleCloseMenu,
    uuid: id,
  });

  return (
    <>
      {/* Desktop (or larger) view */}
      <div ref={containerRef} id={id} className={menuClasses}>
        <DialogTabs
          tabs={TokenTabs}
          activeTab={activeTab}
          onActiveTabChange={(tabId) => onActiveTabChange?.(tabId as TabTypes)}
          onChange={handleTabChange}
        />

        <InputBox
          ref={inputRef}
          id={id}
          type="text"
          placeholder={t("common.search_token")}
          value={enteredTokenName}
          onValueChange={setEnteredTokenName}
          onInput={searchToken}
          className="p-[12px] my-[20px]"
        />
        <ul
          role="listbox"
          id={id}
          className="gap-2 overflow-y-scroll h-[180px]"
        >
          {activeTab === TabTypes.TOKEN ? (
            filteredTokens.map((tk) => {
              const selected = deepEqual(tk, value);
              const IconComp = symbolToIconMap[tk.symbol];
              return (
                // svelte-ignore a11y-click-events-have-key-events
                <li
                  key={tk.symbol}
                  role="option"
                  tabIndex={0}
                  aria-selected={selected}
                  className={classNames(
                    "rounded-[10px] my-[8px]",
                    selected ? "bg-tertiary-interactive-accent" : undefined,
                  )}
                  onClick={() => selectToken(tk)}
                  onKeyDown={getTokenKeydownHandler(tk)}
                >
                  <div className="p-4">
                    {/* Only match icons to configurd tokens */}
                    {IconComp && !tk.imported ? (
                      <i role="img" aria-label={tk.name}>
                        <IconComp size={28} />
                      </i>
                    ) : tk.logoURI ? (
                      <img
                        src={tk.logoURI}
                        alt={tk.name}
                        className="w-[28px] h-[28px] rounded-[50%]"
                      />
                    ) : (
                      <i role="img" aria-label={tk.symbol}>
                        <Erc20 size={28} />
                      </i>
                    )}
                    <span className="body-bold">{tk.symbol}</span>
                  </div>
                </li>
              );
            })
          ) : activeTab === TabTypes.CUSTOM && !onlyMintable ? (
            <>
              {filteredCustomTokens.map((ct, index) => (
                <li key={index}>
                  <div className="p-4 flex">
                    <i
                      role="option"
                      tabIndex={0}
                      aria-selected={ct === value}
                      onClick={() => selectToken(ct)}
                      onKeyDown={getTokenKeydownHandler(ct)}
                      aria-label={ct.name}
                    >
                      <Erc20 />
                    </i>
                    <span
                      role="option"
                      aria-selected={ct === value}
                      tabIndex={-1}
                      onClick={() => selectToken(ct)}
                      onKeyDown={getTokenKeydownHandler(ct)}
                      className="grow body-bold"
                    >
                      {truncateString(ct.symbol, 10)}
                    </span>
                    <div
                      role="button"
                      tabIndex={-1}
                      onClick={() => removeToken(ct)}
                      onKeyDown={getTokenKeydownHandler(ct)}
                      className="cursor-pointer"
                    >
                      <Icon
                        type="trash"
                        size={25}
                        fillClass="fill-primary-icon"
                      />
                    </div>
                  </div>
                </li>
              ))}

              <div className="h-sep my-[8px]" />
              <li>
                <button
                  onClick={showAddERC20}
                  className="flex hover:bg-dark-5 justify-center items-center rounded-lg h-[64px]"
                >
                  {/* Original passed `vWidth`/`vHeight` which the Icon component
                          does not declare, so Svelte ignored them — only `size` took
                          effect. Preserved verbatim for pixel parity. */}
                  <Icon
                    type="plus-circle"
                    fillClass="fill-primary-icon"
                    size={32}
                  />
                  <span
                    className="
                      body-bold
                      bg-transparent
                      flex-1
                      px-0"
                  >
                    {t("token_dropdown.add_custom")}
                  </span>
                </button>
              </li>
            </>
          ) : null}
        </ul>
      </div>
      <AddCustomErc20
        modalOpen={addArc20ModalOpen}
        onModalOpenChange={setAddArc20ModalOpen}
        onTokenRemoved={onTokenRemoved}
      />

      <OnAccount change={onAccountChange} />
    </>
  );
}
