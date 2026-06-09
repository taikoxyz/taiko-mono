"use client";

import { useMemo } from "react";
import type { Hash } from "viem";

import ActionButton from "@/components/Button/ActionButton";
import { Icon, type IconType } from "@/components/Icon";
import { Spinner } from "@/components/Spinner";
import { chainConfig } from "@/config/generated/chainConfig";
import { useTranslation } from "@/i18n/useTranslation";
import type { BridgeTransaction } from "@/libs/bridge";
import { useThemeStore } from "@/stores/useThemeStore";

export interface ClaimConfirmStepProps {
  canClaim?: boolean;
  claimingDone?: boolean;
  claiming?: boolean;
  bridgeTx: BridgeTransaction;
  txHash: Hash;
  // canForceTransaction?: boolean;
  /** Svelte `dispatch('claim')` -> callback prop. */
  onClaim?: () => void;
  // onForceClaim?: () => void;
}

export default function ClaimConfirmStep({
  canClaim = false,
  claimingDone = false,
  claiming = false,
  bridgeTx,
  txHash,
  onClaim,
}: ClaimConfirmStepProps) {
  const { t } = useTranslation();
  const theme = useThemeStore((state) => state.theme);

  const handleClaimClick = async () => {
    onClaim?.();
  };

  // const handleForceClaim = async () => {
  //   onForceClaim?.();
  // };

  // const getSuccessTitle = () => $t('bridge.step.confirm.success.claim');
  // $: statusTitle = getSuccessTitle();
  const statusTitle = t("bridge.step.confirm.success.claim");

  // $: if (txHash && claimingDone) { getSuccessDescription(); }
  // let successDescription = '';
  const successDescription = useMemo(() => {
    if (!(txHash && claimingDone)) return "";
    if (!txHash) return "";

    const explorer =
      chainConfig[Number(bridgeTx.destChainId)]?.blockExplorers?.default.url;
    const url = `${explorer}/tx/${txHash}`;

    return t("transactions.actions.claim.success.message", { url });
  }, [txHash, claimingDone, bridgeTx.destChainId, t]);

  // $: bridgeIcon = `bridge-${$theme}` as IconType;
  const bridgeIcon = `bridge-${theme}` as IconType;
  // $: successIcon = `success-${$theme}` as IconType;
  const successIcon = `success-${theme}` as IconType;

  // $: claimDisabled = !canClaim || claiming;
  const claimDisabled = !canClaim || claiming;

  return (
    <div className="space-y-[18px]">
      <div className="mt-[30px]">
        <section id="txStatus">
          <div className="flex flex-col justify-content-center items-center">
            {claimingDone ? (
              <>
                <Icon type={successIcon} size={160} />
                <div id="text" className="f-col my-[30px] text-center">
                  <h1 dangerouslySetInnerHTML={{ __html: statusTitle }} />
                  <span
                    className=""
                    dangerouslySetInnerHTML={{ __html: successDescription }}
                  />
                </div>
              </>
            ) : claiming ? (
              <>
                <Spinner className="!w-[160px] !h-[160px] text-primary-brand" />
                <div id="text" className="f-col my-[30px] text-center">
                  <h1 className="mb-[16px]">
                    {t("bridge.step.confirm.processing")}
                  </h1>
                  <span>{t("bridge.step.confirm.approve.pending")}</span>
                </div>
              </>
            ) : !claiming && !claimingDone ? (
              <>
                <Icon type={bridgeIcon} size={160} />
                <div id="text" className="f-col my-[30px] text-center">
                  <h1 className="mb-[16px]">
                    {t("transactions.claim.steps.confirm.proceed")}
                  </h1>
                  <span>
                    {t("transactions.claim.steps.confirm.claim_description")}
                  </span>
                </div>
              </>
            ) : null}
          </div>
        </section>
        {!claimingDone ? (
          <section id="actions" className="f-col w-full gap-2">
            <div className="h-sep mb-[30px]" />
            <ActionButton
              onPopup
              priority="primary"
              loading={claiming}
              onClick={() => handleClaimClick()}
              disabled={claimDisabled}
            >
              {t("transactions.claim.steps.confirm.claim_button")}
            </ActionButton>
            {/* {canForceTransaction ? (
              <ActionButton
                onPopup
                priority="primary"
                loading={claiming}
                onClick={() => handleForceClaim()}
                disabled={claimDisabled}>
                Force transaction
              </ActionButton>
            ) : null} */}
          </section>
        ) : null}
      </div>
    </div>
  );
}
