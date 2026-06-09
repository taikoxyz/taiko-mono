"use client";

import { getBalance, switchChain } from "@wagmi/core";
import {
  forwardRef,
  useCallback,
  useEffect,
  useImperativeHandle,
  useMemo,
  useState,
} from "react";
import { type Address, getAddress, parseEther } from "viem";

import Alert from "@/components/Alert/Alert";
import { ActionButton } from "@/components/Button";
import { Icon } from "@/components/Icon";
import Spinner from "@/components/Spinner/Spinner";
import { Tooltip } from "@/components/Tooltip";
import { claimConfig } from "$config";
import { useTranslation } from "@/i18n/useTranslation";
import { type BridgeTransaction } from "@/libs/bridge";
import { getChainName } from "@/libs/chain";
import { shortenAddress } from "@/libs/util/shortenAddress";
import { config } from "@/libs/wagmi";
import { useAccount } from "@/stores/account";
import {
  switchingNetwork,
  useConnectedSourceChain,
  useSwitchingNetwork,
} from "@/stores/network";

export interface ClaimPreCheckProps {
  tx: BridgeTransaction;
  /** Two-way bound in the original (`bind:canContinue`). */
  canContinue?: boolean;
  onCanContinueChange?: (value: boolean) => void;
  /** Two-way bound in the original (`bind:hideContinueButton`). */
  hideContinueButton?: boolean;
  onHideContinueButtonChange?: (value: boolean) => void;
  /** Svelte `dispatch('closeDialog')` -> callback prop. */
  onCloseDialog?: () => void;
}

/** Imperative handle mirroring Svelte's `export const closeDialog`. */
export interface ClaimPreCheckHandle {
  closeDialog: () => void;
}

const ClaimPreCheck = forwardRef<ClaimPreCheckHandle, ClaimPreCheckProps>(
  function ClaimPreCheck(
    {
      tx,
      canContinue = false,
      onCanContinueChange,
      hideContinueButton = false,
      onHideContinueButtonChange,
      onCloseDialog,
    },
    ref,
  ) {
    const { t } = useTranslation();

    // `$account` reactive subscription (the watcher writes the vanilla store).
    const account = useAccount((state) => state);
    // `$connectedSourceChain` / `$switchingNetwork` reactive subscriptions.
    const connectedSourceChainValue = useConnectedSourceChain();
    const switchingNetworkValue = useSwitchingNetwork();

    // let checkingPrerequisites: boolean;
    const [checkingPrerequisites, setCheckingPrerequisites] =
      useState<boolean>(false);
    // $: hasEnoughEth = false; (also set inside checkConditions)
    const [hasEnoughEth, setHasEnoughEth] = useState(false);

    const closeDialog = useCallback(() => {
      onCloseDialog?.();
    }, [onCloseDialog]);

    useImperativeHandle(ref, () => ({ closeDialog }), [closeDialog]);

    const switchChains = async () => {
      switchingNetwork.setState(true);
      try {
        await switchChain(config, { chainId: Number(tx.destChainId) });
      } catch (err) {
        console.error(err);
      } finally {
        switchingNetwork.setState(false);
      }
    };

    const checkEnoughBalance = useCallback(
      async (address: Maybe<Address>, chainId: number) => {
        if (!address) {
          return false;
        }

        const balance = await getBalance(config, { address, chainId });

        if (
          balance.value >= parseEther(String(claimConfig.minimumEthToClaim))
        ) {
          return true;
        }
        return false;
      },
      [],
    );

    const checkConditions = useCallback(async () => {
      setCheckingPrerequisites(true);

      const results = await Promise.allSettled([
        checkEnoughBalance(account?.address, Number(tx.destChainId)),
      ]);

      results.forEach((result, index) => {
        if (result.status === "fulfilled") {
          if (index === 0) {
            setHasEnoughEth(result.value);
          }
        } else {
          // You can log or handle errors here if a promise was rejected.
          console.error(`Error in promise at index ${index}:`, result.reason);
        }
      });
      setCheckingPrerequisites(false);
    }, [account?.address, checkEnoughBalance, tx.destChainId]);

    // $: txDestChainName = getChainName(Number(tx.destChainId));
    const txDestChainName = useMemo(
      () => getChainName(Number(tx.destChainId)),
      [tx.destChainId],
    );

    // $: correctChain = Number(tx.destChainId) === $connectedSourceChain?.id;
    const correctChain =
      Number(tx.destChainId) === connectedSourceChainValue?.id;

    // $: hasPaidProcessingFee = tx.processingFee > 0;
    const hasPaidProcessingFee = tx.processingFee > 0;

    // $: onlyDestOwnerCanClaimWarning = false; + $: if (...) {...}
    const onlyDestOwnerCanClaimWarning = useMemo(() => {
      if (tx.message?.to && account?.address && tx.message.destOwner) {
        const destOwnerMustClaim = tx.message.gasLimit === 0; // If gasLimit is 0, the destOwner must claim
        const isDestOwner =
          getAddress(account.address) === getAddress(tx.message.destOwner);

        if (destOwnerMustClaim && !isDestOwner) {
          return true;
        }
        return false;
      }
      return false;
    }, [
      tx.message?.to,
      tx.message?.destOwner,
      tx.message?.gasLimit,
      account?.address,
    ]);

    // $: successfulPreChecks = correctChain && hasEnoughEth;
    const successfulPreChecks = correctChain && hasEnoughEth;

    // $: if (!checkingPrerequisites && successfulPreChecks && $account && !onlyDestOwnerCanClaimWarning) {
    //      hideContinueButton = false; canContinue = true;
    //    } else { if (!correctChain) hideContinueButton = true; canContinue = false; }
    useEffect(() => {
      if (
        !checkingPrerequisites &&
        successfulPreChecks &&
        account &&
        !onlyDestOwnerCanClaimWarning
      ) {
        if (hideContinueButton !== false) onHideContinueButtonChange?.(false);
        if (canContinue !== true) onCanContinueChange?.(true);
      } else {
        if (!correctChain) {
          if (hideContinueButton !== true) onHideContinueButtonChange?.(true);
        }
        if (canContinue !== false) onCanContinueChange?.(false);
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [
      checkingPrerequisites,
      successfulPreChecks,
      account,
      onlyDestOwnerCanClaimWarning,
      correctChain,
    ]);

    // $: $account && checkConditions();
    useEffect(() => {
      if (account) {
        checkConditions();
      }
    }, [account, checkConditions]);

    // onMount(() => { checkConditions(); });
    useEffect(() => {
      checkConditions();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    return (
      <div className="space-y-[25px] mt-[20px]">
        <div className="flex justify-between mb-2 items-center">
          <div className="font-bold text-primary-content">
            {t("transactions.claim.steps.pre_check.title")}
          </div>
        </div>
        <div className="min-h-[150px] grid content-between">
          {onlyDestOwnerCanClaimWarning ? (
            <div className="f-between-center">
              <div className="f-row gap-1">
                <div className="f-col">
                  <Alert type="info">
                    {t(
                      "transactions.claim.steps.pre_check.only_destowner_can_claim",
                    )}
                    <div className="h-sep" />
                    <span className="font-bold">
                      {t("common.owner.destination")}:{" "}
                    </span>
                    {shortenAddress(tx.message?.destOwner, 6, 4)}
                  </Alert>
                </div>
              </div>
              {checkingPrerequisites ? <Spinner /> : null}
            </div>
          ) : (
            <div>
              <div className="f-between-center">
                <div className="f-row gap-1">
                  <span className="text-secondary-content">
                    {t("transactions.claim.steps.pre_check.chain_check")}
                  </span>
                  <Tooltip>
                    <h2>
                      {t(
                        "transactions.claim.steps.pre_check.tooltip.chain.title",
                      )}
                    </h2>

                    <span>
                      {t(
                        "transactions.claim.steps.pre_check.tooltip.chain.description",
                      )}
                    </span>
                  </Tooltip>
                </div>
                {checkingPrerequisites ? (
                  <Spinner />
                ) : correctChain ? (
                  <Icon
                    type="check-circle"
                    fillClass="fill-positive-sentiment"
                  />
                ) : (
                  <Icon
                    type="x-close-circle"
                    fillClass="fill-negative-sentiment"
                  />
                )}
              </div>
              <div className="f-between-center">
                <div className="f-row gap-1">
                  <span className="text-secondary-content">
                    {t("transactions.claim.steps.pre_check.funds_check")}
                  </span>
                  <Tooltip>
                    <h2>
                      {t(
                        "transactions.claim.steps.pre_check.tooltip.funds.title",
                      )}
                    </h2>
                    <span>
                      {t(
                        "transactions.claim.steps.pre_check.tooltip.funds.description",
                      )}{" "}
                    </span>
                  </Tooltip>
                </div>
                {checkingPrerequisites ? (
                  <Spinner />
                ) : hasEnoughEth ? (
                  <Icon
                    type="check-circle"
                    fillClass="fill-positive-sentiment"
                  />
                ) : (
                  <Icon
                    type="x-close-circle"
                    fillClass="fill-negative-sentiment"
                  />
                )}
              </div>
              {hasPaidProcessingFee ? (
                <>
                  <div className="h-sep" />
                  <div className="f-between-center">
                    {checkingPrerequisites ? (
                      <Spinner />
                    ) : (
                      <Alert type="info">
                        {t(
                          "transactions.claim.steps.pre_check.tooltip.processing_fee.description",
                        )}
                      </Alert>
                    )}
                  </div>
                </>
              ) : null}
            </div>
          )}
        </div>
        {!canContinue && !correctChain && !onlyDestOwnerCanClaimWarning ? (
          <>
            <div className="h-sep" />
            <div className="f-col space-y-[16px]">
              <ActionButton
                onPopup
                priority="primary"
                disabled={switchingNetworkValue}
                loading={switchingNetworkValue}
                onClick={() => {
                  switchChains();
                }}
              >
                {t("common.switch_to")} {txDestChainName}
              </ActionButton>
            </div>
          </>
        ) : !canContinue ? (
          <>
            <div className="h-sep" />
            <div className="f-col space-y-[16px]">
              <ActionButton
                onPopup
                priority="primary"
                onClick={() => {
                  closeDialog();
                }}
              >
                {t("common.ok")}
              </ActionButton>
            </div>
          </>
        ) : null}
      </div>
    );
  },
);

export default ClaimPreCheck;
