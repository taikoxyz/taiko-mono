"use client";

import {
  forwardRef,
  useEffect,
  useId,
  useImperativeHandle,
  useRef,
  useState,
  type FormEvent,
} from "react";
import { formatEther } from "viem";

import { Alert, FlatAlert } from "@/components/Alert";
import {
  calculatingProcessingFee,
  gasLimitZero,
  processingFee,
  processingFeeMethod,
  useBridgeState,
} from "@/components/Bridge/state";
import { ActionButton, CloseButton } from "@/components/Button";
import { InputBox, type InputBoxHandle } from "@/components/InputBox";
import { LoadingText } from "@/components/LoadingText";
import { Tooltip } from "@/components/Tooltip";
import { useCloseOnEscapeOrOutsideClick } from "@/libs/customActions";
import { ProcessingFeeMethod } from "@/libs/fee";
import { parseToWei } from "@/libs/util/parseToWei";
import { cn } from "@/lib/utils";
import { useTranslation } from "@/i18n/useTranslation";

import NoneOption from "./NoneOption";
import RecommendedFee from "./RecommendedFee";

/** Public API (Svelte `export function resetProcessingFee`). */
export interface ProcessingFeeHandle {
  resetProcessingFee: () => void;
}

export interface ProcessingFeeProps {
  small?: boolean;
  textOnly?: boolean;
  /** `bind:hasEnoughEth` controlled value + write-back. */
  hasEnoughEth?: boolean;
  onHasEnoughEthChange?: (value: boolean) => void;
  disabled?: boolean;
  /** Maps Svelte `$$props.class` (only used in the textOnly branch). */
  className?: string;
}

const ProcessingFee = forwardRef<ProcessingFeeHandle, ProcessingFeeProps>(
  function ProcessingFee(
    {
      small = false,
      textOnly = false,
      hasEnoughEth = false,
      onHasEnoughEthChange,
      disabled = false,
      className,
    },
    ref,
  ) {
    const { t } = useTranslation();

    const dialogId = `dialog-${useId()}`;

    // Stores (reactive `$`).
    const $calculatingProcessingFee = useBridgeState(calculatingProcessingFee);
    const $processingFee = useBridgeState(processingFee);
    const $processingFeeMethod = useBridgeState(processingFeeMethod);
    const $gasLimitZero = useBridgeState(gasLimitZero);

    const [recommendedAmount, setRecommendedAmount] = useState<bigint>(
      BigInt(0),
    );
    const [
      errorCalculatingRecommendedAmount,
      setErrorCalculatingRecommendedAmount,
    ] = useState(false);

    // calculatingEnoughEth/errorCalculatingEnoughEth are bound from NoneOption but
    // unused for rendering; kept as state for binding parity.
    const [, setCalculatingEnoughEth] = useState(false);
    const [, setErrorCalculatingEnoughEth] = useState(false);

    const [modalOpen, setModalOpen] = useState(false);
    const inputBoxRef = useRef<InputBoxHandle>(null);
    const dialogRef = useRef<HTMLDialogElement>(null);

    const [tempProcessingFeeMethod, setTempProcessingFeeMethod] =
      useState<ProcessingFeeMethod>($processingFeeMethod);
    const tempProcessingFeeRef = useRef<bigint>($processingFee);

    const [manuallyConfirmed, setManuallyConfirmed] = useState(false);

    const focusInputBox = () => {
      inputBoxRef.current?.focus();
    };

    async function updateProcessingFee(
      method: ProcessingFeeMethod,
      recommended: bigint,
    ) {
      switch (method) {
        case ProcessingFeeMethod.RECOMMENDED:
          processingFee.setState(() => recommended, true);
          break;
        case ProcessingFeeMethod.CUSTOM:
          processingFee.setState(() => tempProcessingFeeRef.current, true);
          // We need to wait for the `disabled` attribute on the input to become
          // false before we can focus it (mirrors svelte's `tick().then(...)`).
          Promise.resolve().then(focusInputBox);
          break;
        case ProcessingFeeMethod.NONE:
          processingFee.setState(() => BigInt(0), true);
          break;
      }
    }

    // Public API.
    useImperativeHandle(
      ref,
      () => ({
        resetProcessingFee: () => {
          inputBoxRef.current?.clear();
          processingFeeMethod.setState(
            () => ProcessingFeeMethod.RECOMMENDED,
            true,
          );
        },
      }),
      [],
    );

    function confirmChanges() {
      if (tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM) {
        // Let's check if we are closing with CUSTOM method selected and the input box is empty
        if (inputBoxRef.current?.getValue() === "") {
          // If so, let's switch to RECOMMENDED method
          processingFeeMethod.setState(
            () => ProcessingFeeMethod.RECOMMENDED,
            true,
          );
        } else {
          if (processingFeeMethod.getState() === tempProcessingFeeMethod) {
            updateProcessingFee(
              processingFeeMethod.getState(),
              recommendedAmount,
            );
          } else {
            processingFeeMethod.setState(() => tempProcessingFeeMethod, true);
          }
        }
      } else {
        inputBoxRef.current?.clear();
        processingFeeMethod.setState(() => tempProcessingFeeMethod, true);
      }
      closeModal();
    }

    function closeModal() {
      setModalOpen(false);
      setManuallyConfirmed(false);
    }

    function openModal() {
      setTempProcessingFeeMethod(processingFeeMethod.getState());
      setModalOpen(true);
      gasLimitZero.setState(() => false, true);
      setManuallyConfirmed(false);
    }

    function cancelModal() {
      inputBoxRef.current?.clear();
      gasLimitZero.setState(() => false, true);

      if (tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM) {
        tempProcessingFeeRef.current = processingFee.getState();
      }
      closeModal();
    }

    function inputProcessFee(event: FormEvent<HTMLInputElement>) {
      if (tempProcessingFeeMethod !== ProcessingFeeMethod.CUSTOM) return;

      const initialValue = (event.target as HTMLInputElement).value;
      if (parseToWei(initialValue) <= recommendedAmount) {
        // If the user tries to input 0 or less, we set it to the current recommended amount
        inputBoxRef.current?.setValue(formatEther(recommendedAmount));
      }
      const finalValue = (event.target as HTMLInputElement).value;
      tempProcessingFeeRef.current = parseToWei(finalValue);
    }

    const handleGasLimitZero = () => {
      const next = !gasLimitZero.getState();
      gasLimitZero.setState(() => next, true);
      if (next) {
        setTempProcessingFeeMethod(ProcessingFeeMethod.NONE);
      } else {
        setTempProcessingFeeMethod(ProcessingFeeMethod.RECOMMENDED);
      }
    };

    // $: { updateProcessingFee($processingFeeMethod, recommendedAmount); }
    useEffect(() => {
      updateProcessingFee($processingFeeMethod, recommendedAmount);
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [$processingFeeMethod, recommendedAmount]);

    // $: unselectNoneIfNotEnoughETH($processingFeeMethod, hasEnoughEth);
    useEffect(() => {
      if (
        $processingFeeMethod === ProcessingFeeMethod.NONE &&
        hasEnoughEth === false
      ) {
        processingFeeMethod.setState(
          () => ProcessingFeeMethod.RECOMMENDED,
          true,
        );
        updateProcessingFee(ProcessingFeeMethod.RECOMMENDED, recommendedAmount);
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [$processingFeeMethod, hasEnoughEth]);

    // $: needsConfirmation / $: confirmDisabled
    const needsConfirmation =
      tempProcessingFeeMethod !== ProcessingFeeMethod.RECOMMENDED ||
      $gasLimitZero;
    const confirmDisabled = needsConfirmation && !manuallyConfirmed;

    // use:closeOnEscapeOrOutsideClick
    useCloseOnEscapeOrOutsideClick(dialogRef, {
      enabled: modalOpen,
      callback: () => setModalOpen(false),
      uuid: dialogId,
    });

    const setHasEnoughEth = (value: boolean) => onHasEnoughEthChange?.(value);

    const customizedSuffix =
      $processingFee !== recommendedAmount ? (
        <span className="text-primary-link">| {t("common.customized")}</span>
      ) : null;

    return (
      <>
        {small ? (
          <div className="ProcessingFee">
            <div className="f-between-center">
              <span className="text-secondary-content">
                {t("processing_fee.title")}
              </span>
              <span className=" text-primary-content mt-[4px]">
                {$calculatingProcessingFee ? (
                  <>
                    <LoadingText mask="0.0017730224073" /> ETH
                  </>
                ) : errorCalculatingRecommendedAmount &&
                  $processingFeeMethod === ProcessingFeeMethod.RECOMMENDED ? (
                  <FlatAlert
                    type="warning"
                    message={t("processing_fee.recommended.error")}
                  />
                ) : (
                  <>
                    {formatEther($processingFee ?? BigInt(0))} ETH{" "}
                    {customizedSuffix}
                  </>
                )}
              </span>
            </div>
          </div>
        ) : textOnly ? (
          <span className={cn("text-primary-content mt-[4px]", className)}>
            {$calculatingProcessingFee ? (
              <LoadingText mask="0.0017730224073" />
            ) : errorCalculatingRecommendedAmount &&
              $processingFeeMethod === ProcessingFeeMethod.RECOMMENDED ? (
              <span className="text-warning-sentiment">
                {t("processing_fee.recommended.error")}
              </span>
            ) : (
              <>
                {formatEther($processingFee ?? BigInt(0))} ETH{" "}
                {customizedSuffix}
              </>
            )}
          </span>
        ) : (
          <div className="ProcessingFee">
            <div className="f-between-center">
              <div className="flex space-x-2">
                <span className="body-small-bold text-primary-content">
                  {t("processing_fee.title")}
                </span>
                <Tooltip>
                  <h2>{t("processing_fee.tooltip_title")}</h2>
                  {t("processing_fee.tooltip")}
                </Tooltip>
              </div>
              {!disabled && (
                <button className="link" onClick={openModal}>
                  {t("common.edit")}
                </button>
              )}
            </div>

            <span className="body-small-regular text-secondary-content mt-[4px]">
              {$calculatingProcessingFee ? (
                <>
                  <LoadingText mask="0.0001" /> ETH
                </>
              ) : errorCalculatingRecommendedAmount &&
                $processingFeeMethod === ProcessingFeeMethod.RECOMMENDED ? (
                <FlatAlert
                  type="warning"
                  message={t("processing_fee.recommended.error")}
                />
              ) : (
                <>
                  {formatEther($processingFee ?? BigInt(0))} ETH{" "}
                  {customizedSuffix}
                </>
              )}
            </span>

            <dialog
              id={dialogId}
              ref={dialogRef}
              className={cn("modal", modalOpen && "modal-open")}
            >
              <div className="modal-box relative px-6 py-[35px] md:rounded-[20px] bg-neutral-background">
                <CloseButton onClick={cancelModal} />

                <div className="w-full">
                  <h3 className="title-body-bold mb-7">
                    {t("processing_fee.title")}
                  </h3>

                  <p className="body-regular text-secondary-content mb-3">
                    {t("processing_fee.description")}
                  </p>

                  <ul className="space-y-7">
                    {/* RECOMMENDED */}
                    <li className="f-between-center">
                      <div className="f-col">
                        <label
                          htmlFor="input-recommended"
                          className="body-bold"
                        >
                          {t("processing_fee.recommended.label")}
                        </label>
                        <span className="body-small-regular text-secondary-content">
                          {/* TODO: think about the UI for this part. Talk to Jane */}
                          {$calculatingProcessingFee ? (
                            <>
                              <LoadingText mask="0.0001" /> ETH
                            </>
                          ) : errorCalculatingRecommendedAmount ? (
                            <FlatAlert
                              type="warning"
                              message={t("processing_fee.recommended.error")}
                            />
                          ) : (
                            <>{formatEther(recommendedAmount)} ETH</>
                          )}
                        </span>
                      </div>
                      <input
                        id="input-recommended"
                        className="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                        type="radio"
                        disabled={$gasLimitZero}
                        value={ProcessingFeeMethod.RECOMMENDED}
                        name="processingFeeMethod"
                        checked={
                          tempProcessingFeeMethod ===
                          ProcessingFeeMethod.RECOMMENDED
                        }
                        onChange={() =>
                          setTempProcessingFeeMethod(
                            ProcessingFeeMethod.RECOMMENDED,
                          )
                        }
                      />
                    </li>

                    {/* NONE */}
                    <li className="space-y-2">
                      <div className="f-between-center">
                        <div className="f-col">
                          <label htmlFor="input-none" className="body-bold">
                            {t("processing_fee.none.label")}
                          </label>
                          <span className="body-small-regular text-secondary-content">
                            {t("processing_fee.none.text")}
                          </span>
                        </div>
                        <input
                          id="input-none"
                          className="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                          type="radio"
                          disabled={!hasEnoughEth}
                          value={ProcessingFeeMethod.NONE}
                          name="processingFeeMethod"
                          checked={
                            tempProcessingFeeMethod === ProcessingFeeMethod.NONE
                          }
                          onChange={() =>
                            setTempProcessingFeeMethod(ProcessingFeeMethod.NONE)
                          }
                        />
                      </div>

                      <NoneOption
                        enoughEth={hasEnoughEth}
                        onEnoughEthChange={setHasEnoughEth}
                        onCalculatingChange={setCalculatingEnoughEth}
                        onErrorChange={setErrorCalculatingEnoughEth}
                        selected={
                          tempProcessingFeeMethod === ProcessingFeeMethod.NONE
                        }
                      />
                    </li>

                    {/* CUSTOM */}
                    <li className="f-between-center">
                      <div className="f-col">
                        <label htmlFor="input-custom" className="body-bold">
                          {t("processing_fee.custom.label")}
                        </label>
                        <span className="body-small-regular text-secondary-content">
                          {t("processing_fee.custom.text")}
                        </span>
                      </div>
                      <input
                        id="input-custom"
                        className="radio w-6 h-6 checked:bg-primary-interactive-accent hover:border-primary-interactive-hover"
                        type="radio"
                        disabled={$gasLimitZero}
                        value={ProcessingFeeMethod.CUSTOM}
                        name="processingFeeMethod"
                        checked={
                          tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM
                        }
                        onChange={() =>
                          setTempProcessingFeeMethod(ProcessingFeeMethod.CUSTOM)
                        }
                      />
                    </li>

                    <div className="relative f-items-center my-[20px]">
                      {tempProcessingFeeMethod ===
                        ProcessingFeeMethod.CUSTOM && (
                        <>
                          <InputBox
                            ref={inputBoxRef}
                            type="number"
                            min="0"
                            placeholder="0.0015"
                            disabled={
                              tempProcessingFeeMethod !==
                              ProcessingFeeMethod.CUSTOM
                            }
                            className="w-full input-box p-6 pr-16 title-subsection-bold placeholder:text-tertiary-content"
                            onInput={inputProcessFee}
                          />
                          <span className="absolute right-6 uppercase body-bold text-secondary-content">
                            ETH
                          </span>
                        </>
                      )}
                    </div>

                    {tempProcessingFeeMethod === ProcessingFeeMethod.CUSTOM && (
                      <div className="my-5">
                        <Alert type="warning">
                          <span className="body-small">
                            {t("processing_fee.custom.warning")}
                          </span>
                        </Alert>
                      </div>
                    )}

                    <div className="f-between-center">
                      <div className="f-col mr-[18px]">
                        <label htmlFor="input-custom" className="body-bold">
                          {" "}
                          {t("processing_fee.gasLimit.title")}
                        </label>
                        <span className="body-small-regular text-secondary-content">
                          {t("processing_fee.gasLimit.message")}
                        </span>
                      </div>
                      <input
                        type="checkbox"
                        checked={$gasLimitZero}
                        onClick={handleGasLimitZero}
                        onChange={() => {}}
                        className="checkbox checkbox-primary"
                      />
                    </div>

                    {$gasLimitZero && (
                      <div className="my-5">
                        <Alert type="warning">
                          <span className="body-small">
                            {t("processing_fee.gasLimit.warning.message")}
                          </span>
                        </Alert>
                      </div>
                    )}
                    {needsConfirmation && (
                      <>
                        <div className="h-sep" />
                        <div className="f-between-center">
                          <div className="f-col mr-[18px]">
                            <label htmlFor="input-custom" className="body-bold">
                              {" "}
                              Confirm changes
                            </label>
                            <span className="body-small-regular text-secondary-content">
                              &quot;I understand the changes I&apos;ve
                              made&quot;
                            </span>
                          </div>
                          <input
                            type="checkbox"
                            checked={manuallyConfirmed}
                            onClick={() =>
                              setManuallyConfirmed(!manuallyConfirmed)
                            }
                            onChange={() => {}}
                            className="checkbox checkbox-primary"
                          />
                        </div>
                        <div className="h-sep" />
                      </>
                    )}
                    <div className="grid grid-cols-2 gap-[20px]">
                      <ActionButton onClick={cancelModal} priority="secondary">
                        <span className="body-bold">{t("common.cancel")}</span>
                      </ActionButton>

                      <ActionButton
                        priority="primary"
                        onClick={confirmChanges}
                        disabled={confirmDisabled}
                        onPopup
                      >
                        <span className="body-bold">{t("common.confirm")}</span>
                      </ActionButton>
                    </div>
                  </ul>
                </div>
              </div>
            </dialog>
          </div>
        )}

        <RecommendedFee
          onAmountChange={setRecommendedAmount}
          onErrorChange={setErrorCalculatingRecommendedAmount}
        />

        {(small || textOnly) && (
          <NoneOption
            enoughEth={hasEnoughEth}
            onEnoughEthChange={setHasEnoughEth}
            onCalculatingChange={setCalculatingEnoughEth}
            onErrorChange={setErrorCalculatingEnoughEth}
            headless
          />
        )}
      </>
    );
  },
);

export default ProcessingFee;
