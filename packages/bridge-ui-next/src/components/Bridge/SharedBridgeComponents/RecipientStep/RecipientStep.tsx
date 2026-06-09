"use client";

import { forwardRef, useImperativeHandle, useRef } from "react";

import { Alert } from "@/components/Alert";
import {
  ProcessingFee,
  Recipient,
} from "@/components/Bridge/SharedBridgeComponents";
import type { ProcessingFeeHandle } from "../ProcessingFee/ProcessingFee";
import type { RecipientHandle } from "./Recipient";
import { useTranslation } from "@/i18n/useTranslation";

import DestOwner, { type DestOwnerHandle } from "./DestOwner";

/** Public API (Svelte `export const reset`). */
export interface RecipientStepHandle {
  reset: () => void;
}

export interface RecipientStepProps {
  /** `bind:hasEnoughEth` controlled value + write-back. */
  hasEnoughEth?: boolean;
  onHasEnoughEthChange?: (value: boolean) => void;
  needsManualRecipientConfirmation?: boolean;
}

const RecipientStep = forwardRef<RecipientStepHandle, RecipientStepProps>(
  function RecipientStep(
    {
      hasEnoughEth = false,
      onHasEnoughEthChange,
      needsManualRecipientConfirmation = false,
    },
    ref,
  ) {
    const { t } = useTranslation();

    const recipientRef = useRef<RecipientHandle>(null);
    // `destOwnerComponent` is bound in the source but never used; kept for parity.
    const destOwnerRef = useRef<DestOwnerHandle>(null);
    const processingFeeRef = useRef<ProcessingFeeHandle>(null);

    useImperativeHandle(
      ref,
      () => ({
        reset: () => {
          recipientRef.current?.clearRecipient();
          processingFeeRef.current?.resetProcessingFee();
        },
      }),
      [],
    );

    return (
      <>
        <div className="mt-[30px] space-y-[16px]">
          <Recipient ref={recipientRef} />
          <DestOwner ref={destOwnerRef} />
          <ProcessingFee
            ref={processingFeeRef}
            hasEnoughEth={hasEnoughEth}
            onHasEnoughEthChange={onHasEnoughEthChange}
          />
        </div>
        <div className="h-sep my-[30px]" />

        {needsManualRecipientConfirmation && (
          <Alert type="warning">
            {t("bridge.alerts.smart_contract_wallet")}
          </Alert>
        )}
      </>
    );
  },
);

export default RecipientStep;
