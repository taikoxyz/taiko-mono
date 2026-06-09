"use client";

import { useState, type KeyboardEvent } from "react";
import { switchChain } from "@wagmi/core";
import { toast } from "sonner";
import { type Chain, SwitchChainError, UserRejectedRequestError } from "viem";

import { chainConfig } from "$chainConfig";
import { LoadingMask } from "@/components/LoadingMask";
import { chains } from "@/libs/chain";
import { config } from "@/libs/wagmi";
import { useModalStore } from "@/stores/useModalStore";
import { toastConfig } from "$config";
import { useTranslation } from "@/i18n/useTranslation";
import { cn } from "@/lib/utils";

// TODO: We should combine this with the ChainSelector component.
// Or at least share the same base component. There is a lot of code duplication

/**
 * Local warning-toast shim mirroring the original
 * `$components/NotificationToast` `warningToast({ title, message })`:
 * maps to sonner `toast.warning(title, { description: message })`.
 * Matches the pattern already used in libs/bridge/handleBridgeErrors.ts.
 */
const warningToast = ({
  title,
  message,
}: {
  title: string;
  message?: string;
}) =>
  toast.warning(title, {
    description: message,
    duration: toastConfig.duration,
  });

export default function SwitchChainModal() {
  const { t } = useTranslation();

  // $switchChainModal store (vanilla zustand, also driven by libs/wagmi/watcher.ts).
  const switchChainModal = useModalStore((s) => s.switchChainModal);
  const setSwitchChainModal = useModalStore((s) => s.setSwitchChainModal);

  // Local UI flag (was `let switchingNetwork = false`).
  const [switchingNetwork, setSwitchingNetwork] = useState(false);

  function closeModal() {
    setSwitchChainModal(false);
  }

  async function selectChain(chain: Chain) {
    // We want to switch the wallet to the selected network.
    // This will trigger the network switch in the UI also
    setSwitchingNetwork(true);

    try {
      await switchChain(config, { chainId: chain.id });
      closeModal();
    } catch (err) {
      console.error(err);
      if (err instanceof SwitchChainError) {
        warningToast({
          title: t("messages.network.pending.title"),
          message: t("messages.network.pending.message"),
        });
      }
      if (err instanceof UserRejectedRequestError) {
        warningToast({
          title: t("messages.network.rejected.title"),
          message: t("messages.network.rejected.message"),
        });
      }
    } finally {
      setSwitchingNetwork(false);
    }
  }

  function getChainKeydownHandler(chain: Chain) {
    return (event: KeyboardEvent) => {
      if (event.key === "Enter") {
        selectChain(chain);
      }
    };
  }

  return (
    <dialog
      className={cn(
        "modal modal-bottom md:modal-middle",
        switchChainModal && "modal-open",
      )}
    >
      <div className="modal-box relative px-6 py-[35px] md:py-[35px] bg-neutral-background text-primary-content box-shadow-small">
        {switchingNetwork && (
          <LoadingMask
            spinnerClass="border-white"
            text={t("messages.network.switching")}
          />
        )}

        <h3 className="title-body-bold mb-[30px]">{t("switch_modal.title")}</h3>
        <p className="body-regular mb-[20px]">
          {t("switch_modal.description")}
        </p>
        <ul role="menu" className=" w-full">
          {chains.map((chain) => {
            const icon =
              (chainConfig as Record<number, { icon?: string }>)[
                Number(chain.id)
              ]?.icon || "Unknown Chain";
            return (
              <li
                key={chain.id}
                role="menuitem"
                tabIndex={0}
                className="p-4 rounded-[10px] hover:bg-primary-background cursor-pointer w-full"
                onClick={() => selectChain(chain)}
                onKeyDown={getChainKeydownHandler(chain)}
              >
                {/* TODO: agree on hover:bg color */}
                <div className="f-row f-items-center justify-between w-full">
                  <div className="f-items-center space-x-4">
                    <i role="img" aria-label={chain.name}>
                      {/* eslint-disable-next-line @next/next/no-img-element -- pixel parity: keep the original <img> markup verbatim */}
                      <img
                        src={icon}
                        alt="chain-logo"
                        className="rounded-full"
                        width="30px"
                        height="30px"
                      />
                    </i>
                    <span className="body-bold">{chain.name}</span>
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      </div>
    </dialog>
  );
}
