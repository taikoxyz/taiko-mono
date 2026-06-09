"use client";

import type { Chain } from "viem";

import { chainConfig } from "@/config/generated/chainConfig";
import { chains } from "@/libs/chain";
import type { ChainConfigMap } from "@/libs/chain";
import { useCloseOnClickOrEscape } from "@/libs/customActions";
import { classNames } from "@/libs/util/classNames";
import { useConnectedSourceChain } from "@/stores/network";

// The generated chainConfig is typed loosely (Record<string, unknown>); narrow it
// to read `.icon` / `.type`, matching the original `$chainConfig` usage.
const config = chainConfig as unknown as ChainConfigMap;

export interface ChainSelectChangeDetail {
  chain: Chain;
  switchWallet: boolean;
}

export interface ChainsDropdownProps {
  /** Svelte `bind:isOpen` -> controlled `isOpen` + `onIsOpenChange`. */
  isOpen: boolean;
  onIsOpenChange?: (isOpen: boolean) => void;
  /** Svelte `bind:value` -> controlled `value`. The dropdown never writes `value` itself. */
  value?: Maybe<Chain>;
  switchWallet?: boolean;
  /** Svelte `dispatch('change', detail)` -> `onChange(detail)`. */
  onChange?: (detail: ChainSelectChangeDetail) => void;
  /** Svelte `$$props.class`. */
  className?: string;
}

export default function ChainsDropdown({
  isOpen,
  onIsOpenChange,
  value = null,
  switchWallet = false,
  onChange,
  className,
}: ChainsDropdownProps) {
  const $connectedSourceChain = useConnectedSourceChain();

  // $: isDestination = !switchWallet;
  const isDestination = !switchWallet;

  const closeDropDown = () => onIsOpenChange?.(false);

  function selectChain(chain: Chain, switchWallet: boolean) {
    if (chain.id === value?.id) return;
    onChange?.({ chain, switchWallet });
    closeDropDown();
  }

  function getChainKeydownHandler(chain: Chain) {
    return (event: React.KeyboardEvent) => {
      if (event.key === "Enter") {
        selectChain(chain, isDestination);
      }
    };
  }

  // use:closeOnClickOrEscape={{ enabled: isOpen, callback: () => (isOpen = false) }}
  useCloseOnClickOrEscape(isOpen, () => onIsOpenChange?.(false));

  const menuClasses = classNames(
    `menu absolute right-0 w-full p-3 z-30 ${
      isDestination ? "mt-0" : "mt-1"
    }  rounded-b-[10px] bg-neutral-background box-shadow-large`,
    isOpen ? "visible opacity-100" : "invisible opacity-0",
    className,
  );

  return (
    <div className={menuClasses}>
      <ul role="listbox" className="text-primary-content text-sm">
        {chains.map((chain) => {
          const disabled =
            (isDestination && chain.id === $connectedSourceChain?.id) ||
            chain.id === value?.id;
          const icon = config[Number(chain.id)]?.icon || "Unknown Chain";
          return (
            <li
              key={chain.id}
              role="menuitem"
              tabIndex={0}
              className={`rounded-[10px] ${
                disabled
                  ? "opacity-20 pointer-events-none"
                  : "hover:bg-secondary-interactive-hover cursor-pointer"
              }`}
              aria-disabled={disabled}
              onClick={() => {
                if (!disabled) selectChain(chain, !isDestination);
              }}
              onKeyDown={getChainKeydownHandler(chain)}
            >
              <div className="f-row justify-between">
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
            </li>
          );
        })}
      </ul>
    </div>
  );
}
