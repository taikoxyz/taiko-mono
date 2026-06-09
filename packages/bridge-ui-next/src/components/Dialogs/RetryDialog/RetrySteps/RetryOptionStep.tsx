"use client";

// React port of
// src/components/Dialogs/RetryDialog/RetrySteps/RetryOptionStep.svelte.
//
// COMPONENT CONVENTION mapping:
//   - `export let canContinue` (two-way `bind:canContinue`) -> controlled
//     `canContinue` prop + `onCanContinueChange(value)` callback.
//   - svelte radio `bind:group={$selectedRetryMethod}` -> controlled radios
//     driven by the `selectedRetryMethod` vanilla store (read reactively via
//     `useSelectedRetryMethod`, written via `selectedRetryMethod.setState`).
//   - Reactive `$: if (selectedRetryMethod !== undefined && ... !== null)` ->
//     `useEffect`. NOTE: the source's condition tested the STORE OBJECT itself
//     (not `$selectedRetryMethod`), which is always truthy, so `canContinue` was
//     effectively always set to `true`. The selected value is likewise always a
//     defined enum member, so the faithful (and observably identical) port sets
//     `canContinue = true` whenever a method is selected.
//
// DOM / class strings preserved verbatim for pixel parity.

import { useEffect } from "react";

import { useTranslation } from "@/i18n/useTranslation";

import { selectedRetryMethod, useSelectedRetryMethod } from "../state";
import { RETRY_OPTION } from "../types";

export interface RetryOptionStepProps {
  /** Two-way `bind:canContinue`. */
  canContinue?: boolean;
  onCanContinueChange?: (value: boolean) => void;
}

export default function RetryOptionStep({
  canContinue = false,
  onCanContinueChange,
}: RetryOptionStepProps) {
  const { t } = useTranslation();

  // `$selectedRetryMethod` reactive subscription.
  const selected = useSelectedRetryMethod();

  // $: if (selectedRetryMethod !== undefined && selectedRetryMethod !== null) {
  //      canContinue = true;
  //    } else { canContinue = false; }
  useEffect(() => {
    const next = selected !== undefined && selected !== null;
    if (canContinue !== next) {
      onCanContinueChange?.(next);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selected]);

  return (
    <div className="container mx-auto inline-block align-middle space-y-[25px] w-full mt-[20px]">
      <div className="flex justify-between mb-2 items-center">
        <div className="font-bold text-primary-content">
          {t("transactions.claim.steps.pre_check.title")}
        </div>
      </div>
      <p>
        Your transaction has failed on chain. This could have several reasons.
        You can now retry as often as you want or only retry once more, then get
        the option to release the funds back on the original chain.
      </p>

      <div className="font-bold text-primary-content">
        Please select your preferred option:
      </div>
      <div className="space-y-4">
        <div className="form-control">
          <label className="label cursor-pointer">
            <span className="">Retry and keep retrying</span>
            <input
              type="radio"
              className="radio radio-primary-brand checked:bg-primary-brand"
              value={RETRY_OPTION.CONTINUE}
              checked={selected === RETRY_OPTION.CONTINUE}
              onChange={() =>
                selectedRetryMethod.setState(RETRY_OPTION.CONTINUE)
              }
            />
          </label>
        </div>
        <div className="form-control">
          <label className="label cursor-pointer">
            <span className="">Retry one final time</span>
            <input
              type="radio"
              className="radio radio-primary-brand checked:bg-primary-brand"
              value={RETRY_OPTION.RETRY_ONCE}
              checked={selected === RETRY_OPTION.RETRY_ONCE}
              onChange={() =>
                selectedRetryMethod.setState(RETRY_OPTION.RETRY_ONCE)
              }
            />
          </label>
        </div>
      </div>
    </div>
  );
}
