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

import { CloseButton } from "@/components/Button";
import { DialogTabs } from "@/components/DialogTabs";
import { Icon } from "@/components/Icon";
import Erc20 from "@/components/Icon/ERC20";
import { InputBox } from "@/components/InputBox";
import type { InputBoxHandle } from "@/components/InputBox/InputBox";
import { OnAccount } from "@/components/OnAccount";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import { tokenService } from "@/libs/storage/services";
import type { NFT, Token } from "@/libs/token";
import { classNames } from "@/libs/util/classNames";
import { noop } from "@/libs/util/noop";
import { truncateString } from "@/libs/util/truncateString";
import { account } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";

import { symbolToIconMap } from "./symbolToIconMap";
import { TabTypes, TokenTabs } from "./types";

export interface DialogViewProps {
  id: string;
  tokens?: Token[];
  /** Two-way bound custom token list (Svelte `bind:customTokens`). */
  customTokens?: Token[];
  /** Write-back for the two-way bound `customTokens`. */
  onCustomTokensChange?: (tokens: Token[]) => void;
  value?: Maybe<Token | NFT>;
  /** Controlled open state (Svelte `bind:menuOpen`). */
  menuOpen?: boolean;
  /** Write-back for the two-way bound `menuOpen`. */
  onMenuOpenChange?: (open: boolean) => void;
  onlyMintable?: boolean;
  selectToken?: (token: Token) => void;
  closeMenu?: () => void;
  /** Controlled active tab (Svelte `bind:activeTab`). */
  activeTab?: TabTypes;
  /** Write-back for the two-way bound `activeTab`. */
  onActiveTabChange?: (tab: TabTypes) => void;
  /** Svelte `dispatch('tokenRemoved', { token })`. */
  onTokenRemoved?: (detail: { token: Token }) => void;
  /** Svelte `dispatch('openCustomTokenModal')`. */
  onOpenCustomTokenModal?: () => void;
}

export default function DialogView({
  id,
  tokens = [],
  customTokens = [],
  onCustomTokensChange,
  value = null,
  menuOpen = false,
  onMenuOpenChange,
  onlyMintable = false,
  selectToken = noop,
  closeMenu = noop,
  activeTab = TabTypes.TOKEN,
  onActiveTabChange,
  onTokenRemoved,
  onOpenCustomTokenModal,
}: DialogViewProps) {
  const { t } = useTranslation();

  const dialogRef = useRef<HTMLDialogElement>(null);
  const inputRef = useRef<InputBoxHandle>(null);

  const [enteredTokenName, setEnteredTokenName] = useState("");

  const searchToken = (event: React.FormEvent<HTMLInputElement>) => {
    setEnteredTokenName((event.target as HTMLInputElement).value);
  };

  const handleTabChange = (detail: { tabId: string }) => {
    onActiveTabChange?.(detail.tabId as TabTypes);
  };

  const showAddERC20 = () => {
    onMenuOpenChange?.(false);
    onOpenCustomTokenModal?.();
  };

  const onAccountChange = () => {
    if (account.getState()?.address) {
      onCustomTokensChange?.(
        tokenService.getTokens(account.getState()?.address as Address),
      );
    }
  };

  const removeToken = (token: Token) => {
    onTokenRemoved?.({ token });
  };

  const getTokenKeydownHandler = (token: Token) => {
    return (event: ReactKeyboardEvent) => {
      if (event.key === "Enter") {
        selectToken(token);
      }
      if (event.key === "Escape") {
        closeMenu();
      }
    };
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

  // onMount/onDestroy tokenService subscribe/unsubscribe
  useEffect(() => {
    const handleStorageChange = (newTokens: Token[]) => {
      onCustomTokensChange?.(newTokens);
    };
    tokenService.subscribeToChanges(handleStorageChange);
    return () => tokenService.unsubscribeFromChanges(handleStorageChange);
  }, [onCustomTokensChange]);

  useCloseOnEscapeOrOutsideClick(dialogRef, {
    enabled: menuOpen,
    callback: closeMenu,
    uuid: id,
  });

  return (
    <>
      {/* Mobile view */}
      <dialog
        ref={dialogRef}
        id={id}
        className={cn("modal modal-bottom", menuOpen && "modal-open")}
      >
        <div className="modal-box relative px-6 py-[35px] w-full bg-neutral-background absolute">
          <CloseButton onClick={closeMenu} />

          <div className="w-full">
            <h3 className="title-body-bold mb-7">
              {t("token_dropdown.label")}
            </h3>

            <DialogTabs
              tabs={TokenTabs}
              activeTab={activeTab}
              onActiveTabChange={(tabId) =>
                onActiveTabChange?.(tabId as TabTypes)
              }
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
            <ul role="listbox" className="menu p-0">
              {activeTab === TabTypes.TOKEN ? (
                filteredTokens.map((token) => {
                  const selected = deepEqual(token, value);
                  const IconComp = symbolToIconMap[token.symbol];
                  return (
                    // svelte-ignore a11y-click-events-have-key-events
                    <li
                      key={token.symbol}
                      role="option"
                      tabIndex={0}
                      aria-selected={selected}
                      className={classNames(
                        "rounded-[10px]",
                        selected ? "bg-tertiary-interactive-accent" : undefined,
                      )}
                      onClick={() => selectToken(token)}
                    >
                      <div className="p-4">
                        {IconComp && !token.imported ? (
                          <i role="img" aria-label={token.name}>
                            <IconComp size={28} />
                          </i>
                        ) : token.logoURI ? (
                          <img
                            src={token.logoURI}
                            alt={token.name}
                            className="w-[28px] h-[28px] rounded-[50%]"
                          />
                        ) : (
                          <i role="img" aria-label={token.symbol}>
                            <Erc20 size={28} />
                          </i>
                        )}
                        <span className="body-bold">{token.symbol}</span>
                      </div>
                    </li>
                  );
                })
              ) : activeTab === TabTypes.CUSTOM && !onlyMintable ? (
                <>
                  {filteredCustomTokens.map((ct, index) => {
                    const selected = deepEqual(ct, value);
                    return (
                      <li
                        key={index}
                        role="option"
                        tabIndex={0}
                        aria-selected={selected}
                        className={classNames(
                          "rounded-[10px]",
                          selected
                            ? "bg-tertiary-interactive-accent"
                            : undefined,
                        )}
                        onClick={() => selectToken(ct)}
                        onKeyDown={getTokenKeydownHandler(ct)}
                      >
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
                    );
                  })}
                  <li className="f-between-center max-h-[42px]">
                    <button
                      onClick={showAddERC20}
                      className="flex w-full hover:bg-dark-5 justify-center items-center rounded-sm"
                    >
                      <Icon type="plus-circle" fillClass="fill-primary-icon" />
                      <span className=" body-bold bg-transparent flex-1 w-[100px] px-0 pl-2">
                        {t("token_dropdown.add_custom")}
                      </span>
                    </button>
                  </li>
                </>
              ) : null}
            </ul>
          </div>
        </div>
        <button className="overlay-backdrop" data-modal-uuid={id} />
      </dialog>

      <OnAccount change={onAccountChange} />
    </>
  );
}
