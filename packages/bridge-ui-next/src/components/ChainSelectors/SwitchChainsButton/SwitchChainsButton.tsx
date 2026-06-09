"use client";

import { switchChain } from "@wagmi/core";
import { SwitchChainError, UserRejectedRequestError } from "viem";
import { toast } from "sonner";

import { destNetwork } from "@/components/Bridge/state";
import { useBridgeState } from "@/components/Bridge/state";
import { Icon } from "@/components/Icon";
import { setAlternateNetwork } from "@/libs/network/setAlternateNetwork";
import { config } from "@/libs/wagmi";
import { toastConfig } from "@/app.config";
import { useTranslation } from "@/i18n/useTranslation";

// $components/NotificationToast `warningToast({ title, message })` -> sonner
// `toast.warning(title, { description: message })`, matching the convention used
// by the migrated `handleBridgeErrors.ts`.
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

export interface SwitchChainsButtonProps {
  disabled?: boolean;
}

export default function SwitchChainsButton({
  disabled = false,
}: SwitchChainsButtonProps) {
  const { t } = useTranslation();
  // $destNetwork (read reactively for the disabled state and inside the handler).
  const $destNetwork = useBridgeState(destNetwork);

  async function switchToDestChain() {
    if (!destNetwork.getState()) return;

    try {
      await switchChain(config, { chainId: destNetwork.getState()!.id });
      setAlternateNetwork();
    } catch (err) {
      console.error(err);
      if (err instanceof SwitchChainError) {
        warningToast({
          title: t("messages.network.pending.title"),
          message: t("messages.network.pending.message"),
        });
      } else if (err instanceof UserRejectedRequestError) {
        warningToast({
          title: t("messages.network.rejected.title"),
          message: t("messages.network.rejected.message"),
        });
      }
    }
  }

  return (
    <button
      className="f-center rounded-full w-[30px] h-[30px]"
      disabled={!$destNetwork || disabled}
      onClick={switchToDestChain}
    >
      <Icon type="up-down" className="" size={16} />
    </button>
  );
}
