"use client";

import { useEffect } from "react";

import { Alert } from "@/components/Alert";
import {
  allApproved,
  computingBalance,
  destNetwork,
  enteredAmount,
  errorComputingBalance,
  insufficientAllowance,
  insufficientBalance,
  needsApprovalReset,
  recipientAddress,
  selectedToken,
  tokenBalance,
  useBridgeState,
  validatingAmount,
} from "@/components/Bridge/state";
import { ActionButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import { BridgePausedError } from "@/libs/error";
import { TokenType } from "@/libs/token";
import { getTokenApprovalStatus } from "@/libs/token/getTokenApprovalStatus";
import { useAccount, useConnectedSourceChain } from "@/stores";
import { useTranslation } from "@/i18n/useTranslation";

export interface ActionsProps {
  approve: () => Promise<void>;
  bridge: () => Promise<void>;
  resetApproval: () => Promise<void>;

  /** `bind:approving` controlled value + write-back. */
  approving?: boolean;
  onApprovingChange?: (value: boolean) => void;
  /** `bind:bridging` controlled value + write-back. */
  bridging?: boolean;
  onBridgingChange?: (value: boolean) => void;
  /** `bind:resetting` controlled value + write-back. */
  resetting?: boolean;
  onResettingChange?: (value: boolean) => void;
  /** `bind:checking` controlled value + write-back. */
  checking?: boolean;
  onCheckingChange?: (value: boolean) => void;

  disabled?: boolean;
}

export default function Actions({
  approve,
  bridge,
  resetApproval,
  approving = false,
  onApprovingChange,
  bridging = false,
  onBridgingChange,
  resetting = false,
  onResettingChange,
  checking = false,
  onCheckingChange,
  disabled = false,
}: ActionsProps) {
  const { t } = useTranslation();

  const paused = false;

  // Stores (reactive `$`).
  const $selectedToken = useBridgeState(selectedToken);
  const $tokenBalance = useBridgeState(tokenBalance);
  const $recipientAddress = useBridgeState(recipientAddress);
  const $destNetwork = useBridgeState(destNetwork);
  const $insufficientBalance = useBridgeState(insufficientBalance);
  const $insufficientAllowance = useBridgeState(insufficientAllowance);
  const $computingBalance = useBridgeState(computingBalance);
  const $errorComputingBalance = useBridgeState(errorComputingBalance);
  const $validatingAmount = useBridgeState(validatingAmount);
  const $allApproved = useBridgeState(allApproved);
  const $enteredAmount = useBridgeState(enteredAmount);
  const $needsApprovalReset = useBridgeState(needsApprovalReset);
  const $account = useAccount((s) => s);
  const $connectedSourceChain = useConnectedSourceChain();

  function onApproveClick() {
    if (paused) throw new BridgePausedError("Bridge is paused");
    onApprovingChange?.(true);
    approve().finally(() => {
      onApprovingChange?.(false);
    });
  }

  function onBridgeClick() {
    if (paused) throw new BridgePausedError("Bridge is paused");
    onBridgingChange?.(true);
    bridge();
  }

  const onResetApproveClick = async () => {
    onResettingChange?.(true);
    await resetApproval();
    onResettingChange?.(false);
  };

  // onMount
  useEffect(() => {
    (async () => {
      const token = selectedToken.getState();
      if (token) {
        allApproved.setState(() => false, true);
        onCheckingChange?.(true);

        await getTokenApprovalStatus(token);
        onCheckingChange?.(false);
      }
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isERC20 = $selectedToken?.type === TokenType.ERC20;
  const isERC721 = $selectedToken?.type === TokenType.ERC721;
  const isERC1155 = $selectedToken?.type === TokenType.ERC1155;
  const isETH = $selectedToken?.type === TokenType.ETH;

  const isValidBalance =
    isETH || isERC20 || isERC1155
      ? !!($tokenBalance && $tokenBalance.value > 0n)
      : isERC721
        ? true
        : false;

  // Basic conditions so we can even start the bridging process
  const hasAddress = $recipientAddress || $account?.address ? true : false;
  const hasNetworks = $connectedSourceChain?.id && $destNetwork?.id;
  const hasBalance =
    !$insufficientBalance &&
    !$computingBalance &&
    !$errorComputingBalance &&
    isValidBalance;

  const canDoNothing =
    !hasAddress || !hasNetworks || !hasBalance || !$selectedToken || disabled;

  // Conditions to disable/enable buttons
  const disableApprove =
    checking ||
    (isERC20
      ? canDoNothing ||
        $insufficientBalance ||
        $validatingAmount ||
        approving ||
        $allApproved ||
        !$enteredAmount
      : isERC721
        ? $allApproved || approving
        : isERC1155
          ? $allApproved || approving
          : approving);

  const validApprovalStatus = $allApproved;

  // USDT specific, L1 address of USDT contract
  const resetRequired =
    !!$connectedSourceChain &&
    $selectedToken?.addresses[$connectedSourceChain.id] ===
      "0xdAC17F958D2ee523a2206206994597C13D831ec7" &&
    $needsApprovalReset;

  const commonConditions =
    validApprovalStatus &&
    !bridging &&
    hasAddress &&
    hasNetworks &&
    hasBalance &&
    $selectedToken &&
    !$validatingAmount &&
    !$insufficientBalance &&
    $allApproved &&
    !paused;

  const erc20ConditionsSatisfied =
    commonConditions &&
    !canDoNothing &&
    !$insufficientAllowance &&
    $tokenBalance &&
    $enteredAmount;

  const erc721ConditionsSatisfied = commonConditions;

  const erc1155ConditionsSatisfied =
    commonConditions && $enteredAmount && $enteredAmount > 0;

  const ethConditionsSatisfied =
    commonConditions && $enteredAmount && $enteredAmount > 0;

  const disableReset = !resetRequired || resetting;

  const disableBridge = Boolean(
    isERC20
      ? !erc20ConditionsSatisfied
      : isERC721
        ? !erc721ConditionsSatisfied
        : isERC1155
          ? !erc1155ConditionsSatisfied
          : isETH
            ? !ethConditionsSatisfied
            : commonConditions,
  );

  return (
    <div className="f-col w-full gap-4">
      {$selectedToken && !isETH && (
        <>
          {resetRequired ? (
            <>
              <Alert type="info">{t("bridge.usdt_approval.info")}</Alert>
              <ActionButton
                priority="primary"
                disabled={disableReset}
                loading={resetting}
                onClick={onResetApproveClick}
              >
                {resetting ? (
                  <span className="body-bold">
                    {t("bridge.button.resetting")}
                  </span>
                ) : $allApproved ? (
                  <div className="f-items-center">
                    <Icon type="check" />
                    <span className="body-bold">
                      {t("bridge.button.reset")}
                    </span>
                  </div>
                ) : checking ? (
                  <span className="body-bold">
                    {t("bridge.button.validating")}
                  </span>
                ) : (
                  <span className="body-bold">
                    {t("bridge.button.reset_approval")}
                  </span>
                )}
              </ActionButton>
            </>
          ) : (
            <ActionButton
              priority="primary"
              disabled={disableApprove}
              loading={approving || $validatingAmount || checking}
              onClick={onApproveClick}
            >
              {approving ? (
                <span className="body-bold">
                  {t("bridge.button.approving")}
                </span>
              ) : $allApproved ? (
                <div className="f-items-center">
                  <Icon type="check" />
                  <span className="body-bold">
                    {t("bridge.button.approved")}
                  </span>
                </div>
              ) : checking ? (
                <span className="body-bold">
                  {t("bridge.button.validating")}
                </span>
              ) : (
                <span className="body-bold">{t("bridge.button.approve")}</span>
              )}
            </ActionButton>
          )}
        </>
      )}
      <ActionButton
        priority="primary"
        disabled={disableBridge}
        loading={bridging}
        onClick={onBridgeClick}
      >
        {bridging ? (
          <span className="body-bold">{t("bridge.button.bridging")}</span>
        ) : (
          <span className="body-bold">{t("bridge.button.bridge")}</span>
        )}
      </ActionButton>
    </div>
  );
}
