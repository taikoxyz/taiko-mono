"use client";

import { useId, useState } from "react";
import type { Chain } from "viem";

import { chainConfig } from "@/config/generated/chainConfig";
import ChainsDialog from "@/components/ChainSelectors/SelectorDialogs/ChainsDialog";
import ChainsDropdown from "@/components/ChainSelectors/SelectorDialogs/ChainsDropdown";
import type { ChainSelectChangeDetail } from "@/components/ChainSelectors/SelectorDialogs/ChainsDropdown";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import type { ChainConfigMap } from "@/libs/chain";
import { classNames } from "@/libs/util/classNames";
import { truncateString } from "@/libs/util/truncateString";
import { useAccount } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

// The generated chainConfig is typed loosely (Record<string, unknown>); narrow it
// to read `.icon`, matching the original `$chainConfig` usage.
const config = chainConfig as unknown as ChainConfigMap;

export interface ChainPillProps {
  value?: Maybe<Chain> | null;
  label?: string;
  readOnly?: boolean;
  /** Svelte `selectChain` prop (was wired to the dialog/dropdown `change` event). */
  onChange?: (detail: ChainSelectChangeDetail) => void | Promise<void>;
  switchWallet?: boolean;
  /** Svelte `$$props.class`. */
  className?: string;
}

export default function ChainPill({
  value = null,
  label = "",
  readOnly = false,
  onChange,
  switchWallet = false,
  className,
}: ChainPillProps) {
  const { t } = useTranslation();
  // $: disabled = !$account || !$account.isConnected || readOnly;
  const $account = useAccount((a) => a);

  const isDesktopOrLarger = useDesktopOrLarger();

  // let classes = classNames('ChainPill relative', $$props.class);
  const classes = classNames("ChainPill relative", className);

  // let buttonClasses = `... ${$$props.class}`;
  const buttonClasses = `f-row body-regular bg-neutral-background px-2 py-[6px] !rounded-full dark:hover:bg-primary-secondary-hover flex justify-start content-center ${className ?? ""}`;

  const iconSize = "min-w-5 max-w-5 min-h-5 max-h-5";

  // Stable, SSR-safe ids replacing `crypto.randomUUID()` at script init.
  const buttonId = `button-${useId()}`;
  const dialogId = `dialog-${useId()}`;

  const [modalOpen, setModalOpen] = useState(false);

  const handlePillClick = () => {
    if (switchWallet) {
      setModalOpen(true);
    }
  };

  const disabled = !$account || !$account.isConnected || readOnly;

  const icon = value
    ? config[Number(value.id)]?.icon || "Unknown Chain"
    : undefined;

  return (
    <div className={classes}>
      <div className="f-items-center space-x-[10px]">
        {label && (
          <label
            className="text-secondary-content body-regular"
            htmlFor={buttonId}
          >
            {label}:
          </label>
        )}
        <button
          id={buttonId}
          type="button"
          disabled={disabled}
          aria-haspopup="dialog"
          aria-controls={dialogId}
          aria-expanded={modalOpen}
          className={buttonClasses}
          onClick={handlePillClick}
        >
          <div className="f-items-center space-x-2 w-full whitespace-nowrap">
            {!value && <span>{t("chain_selector.placeholder")}</span>}
            {value && (
              <>
                <i role="img" aria-label={value.name}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={icon}
                    alt="chain-logo"
                    className={`rounded-full ${iconSize}`}
                  />
                </i>
                <span>{truncateString(value.name, 8)}</span>
              </>
            )}
          </div>
        </button>
      </div>
      {isDesktopOrLarger ? (
        <ChainsDropdown
          className="rounded-[20px]"
          onChange={onChange}
          isOpen={modalOpen}
          onIsOpenChange={setModalOpen}
          value={value}
          switchWallet={switchWallet}
        />
      ) : (
        <ChainsDialog
          onChange={onChange}
          isOpen={modalOpen}
          onIsOpenChange={setModalOpen}
          value={value}
          switchWallet={switchWallet}
        />
      )}
    </div>
  );
}
