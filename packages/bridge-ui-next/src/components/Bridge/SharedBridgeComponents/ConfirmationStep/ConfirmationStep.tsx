"use client";

import { useEffect, useRef, useState } from "react";
import type { Hash, Hex } from "viem";

import { routingContractsMap } from "$bridgeConfig";
import { chainConfig } from "$chainConfig";
import Actions from "@/components/Bridge/SharedBridgeComponents/Actions";
import {
  allApproved,
  bridgeService,
  destNetwork,
  enteredAmount,
  processingFee,
  recipientAddress,
  selectedNFTs,
  selectedToken,
  useBridgeState,
} from "@/components/Bridge/state";
import { BridgingStatus } from "@/components/Bridge/types";
import { Icon, type IconType } from "@/components/Icon";
import {
  successToast,
  infoToast,
  warningToast,
} from "@/components/NotificationToast";
import { Spinner } from "@/components/Spinner";
import {
  type ApproveArgs,
  bridges,
  type BridgeTransaction,
  MessageStatus,
  type NFTApproveArgs,
} from "@/libs/bridge";
import type { ERC20Bridge } from "@/libs/bridge/ERC20Bridge";
import type { ERC721Bridge } from "@/libs/bridge/ERC721Bridge";
import type { ERC1155Bridge } from "@/libs/bridge/ERC1155Bridge";
import { getBridgeArgs } from "@/libs/bridge/getBridgeArgs";
import { handleBridgeError } from "@/libs/bridge/handleBridgeErrors";
import { BridgePausedError, TransactionTimeoutError } from "@/libs/error";
import { bridgeTxService } from "@/libs/storage";
import { TokenType } from "@/libs/token";
import { getTokenApprovalStatus } from "@/libs/token/getTokenApprovalStatus";
import { isToken } from "@/libs/token/isToken";
import { refreshUserBalance } from "@/libs/util/balance";
import { isBridgePaused } from "@/libs/util/checkForPausedContracts";
import { getConnectedWallet } from "@/libs/util/getConnectedWallet";
import { account } from "@/stores/account";
import { connectedSourceChain } from "@/stores/network";
import { pendingTransactions } from "@/stores/pendingTransactions";
import { useThemeStore } from "@/stores/useThemeStore";
import { useTranslation } from "@/i18n/useTranslation";

// The generated chainConfig is typed loosely (Record<string, unknown>); narrow it to
// the shape we need to read blockExplorers, exactly as the original Svelte component did.
const chains = chainConfig as Record<
  number,
  { blockExplorers?: { default: { url: string } } }
>;

export interface ConfirmationStepProps {
  /** `bind:bridgingStatus` controlled value + write-back. */
  bridgingStatus?: BridgingStatus;
  onBridgingStatusChange?: (status: BridgingStatus) => void;
}

export default function ConfirmationStep({
  bridgingStatus = BridgingStatus.PENDING,
  onBridgingStatusChange,
}: ConfirmationStepProps) {
  const { t } = useTranslation();

  const theme = useThemeStore((s) => s.theme);

  // Stores (reactive `$`).
  const $allApproved = useBridgeState(allApproved);
  const $selectedToken = useBridgeState(selectedToken);

  // Locals (Svelte `let`).
  const [bridging, setBridging] = useState(false);
  const [approving, setApproving] = useState(false);
  const [checking, setChecking] = useState(false);
  const [resetting, setResetting] = useState(false);

  const [icon, setIcon] = useState<IconType>("" as IconType);
  const [iconFill, setIconFill] = useState("");

  const [statusTitle, setStatusTitle] = useState("");
  const [statusDescription, setStatusDescription] = useState("");

  const setBridgingStatus = (status: BridgingStatus) =>
    onBridgingStatusChange?.(status);

  // $: derived icon types.
  const approveIcon = `approve-${theme}` as IconType;
  const bridgeIcon = `bridge-${theme}` as IconType;
  const successIcon = `success-${theme}` as IconType;
  const timeoutIcon = `exclamation-circle` as IconType;

  const handleBridgeTxHash = async (txHash: Hash) => {
    const currentChain = connectedSourceChain.getState()?.id;

    const destinationChain = destNetwork.getState()?.id;
    const userAccount = account.getState()?.address;
    const token = selectedToken.getState();
    if (!currentChain || !destinationChain || !userAccount || !token) return; //TODO error handling

    const explorer = chains[currentChain]?.blockExplorers?.default.url;

    try {
      await pendingTransactions.add(txHash, currentChain);

      successToast({
        title: t("bridge.actions.bridge.success.title"),
        message: t("bridge.actions.bridge.success.message", {
          token: token.symbol,
        }),
      });
      setIcon(successIcon);
      setBridgingStatus(BridgingStatus.DONE);
      setStatusTitle(t("bridge.actions.bridge.success.title"));
      setStatusDescription(
        t("bridge.step.confirm.bridge.success.message", {
          url: `${explorer}/tx/${txHash}`,
        }),
      );
    } catch (error) {
      if (error instanceof TransactionTimeoutError) {
        handleTimeout(txHash);
      } else {
        handleBridgeError(error as Error);
      }
    }

    const bridgeTx = {
      srcTxHash: txHash,
      from: userAccount,
      amount: enteredAmount.getState(),
      symbol: token.symbol,
      decimals: isToken(token) ? token.decimals : undefined,
      srcChainId: BigInt(currentChain),
      destChainId: BigInt(destinationChain),
      tokenType: token.type,
      msgStatus: MessageStatus.NEW,
      // eslint-disable-next-line react-hooks/purity -- runs inside the async bridge callback, not during render
      timestamp: Date.now(),
    } as BridgeTransaction;
    setBridging(false);

    bridgeTxService.addTxByAddress(userAccount, bridgeTx);
  };

  const handleTimeout = (txHash: Hex) => {
    const currentChain = connectedSourceChain.getState()?.id;
    const explorer = currentChain
      ? chains[currentChain]?.blockExplorers?.default.url
      : undefined;

    warningToast({
      title: t("bridge.actions.bridge.timeout.title"),
      message: t("bridge.actions.bridge.timeout.message", {
        url: `${explorer}/tx/${approveTxHashRef.current}`,
      }),
    });
    setIcon(timeoutIcon);
    setIconFill("fill-warning-sentiment");
    setBridgingStatus(BridgingStatus.DONE);
    setStatusTitle(t("bridge.actions.bridge.timeout.title"));
    setStatusDescription(
      t("bridge.step.confirm.bridge.timeout.message", {
        url: `${explorer}/tx/${txHash}`,
      }),
    );
  };

  const handleApproveTxHash = async (txHash: Hash) => {
    const currentChain = connectedSourceChain.getState()?.id;

    const destinationChain = destNetwork.getState()?.id;
    const userAccount = account.getState()?.address;
    const token = selectedToken.getState();
    if (!currentChain || !destinationChain || !userAccount || !token) return; //TODO error handling

    const explorer = chains[currentChain]?.blockExplorers?.default.url;

    infoToast({
      title: t("bridge.actions.approve.tx.title"),
      message: t("bridge.actions.approve.tx.message", {
        token: token.symbol,
        url: `${explorer}/tx/${approveTxHashRef.current}`,
      }),
    });

    refreshUserBalance();
    try {
      await pendingTransactions.add(
        approveTxHashRef.current as Hash,
        currentChain,
      );

      setStatusTitle(t("bridge.actions.approve.success.title"));
      setStatusDescription(
        t("bridge.step.confirm.approve.success.message", {
          url: `${explorer}/tx/${txHash}`,
        }),
      );

      await getTokenApprovalStatus(token);

      successToast({
        title: t("bridge.actions.approve.success.title"),
        message: t("bridge.actions.approve.success.message", {
          token: token.symbol,
        }),
      });
    } catch (error) {
      if (error instanceof TransactionTimeoutError) {
        handleTimeout(txHash);
      } else {
        handleBridgeError(error as Error);
      }
    }
  };

  // `let approveTxHash` / `let bridgeTxHash` — mutated across async callbacks, so refs.
  const approveTxHashRef = useRef<Hash | undefined>(undefined);
  const bridgeTxHashRef = useRef<Hash | undefined>(undefined);

  async function resetApproval() {
    const token = selectedToken.getState();
    const srcChain = connectedSourceChain.getState();
    const dest = destNetwork.getState();
    if (!token || !srcChain || !dest?.id) return;
    try {
      const tokenAddress = token.addresses[srcChain.id];
      const type: TokenType = token.type;

      const spenderAddress =
        routingContractsMap[srcChain.id][dest.id].erc20VaultAddress;
      const walletClient = await getConnectedWallet(srcChain.id);

      const args: ApproveArgs = {
        tokenAddress,
        spenderAddress,
        wallet: walletClient,
        amount: 0n,
      };
      approveTxHashRef.current = await (bridges[type] as ERC20Bridge).approve(
        args,
        true,
      );

      if (approveTxHashRef.current)
        await handleApproveTxHash(approveTxHashRef.current);
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  async function approve() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError("Bridge is paused");
    });

    try {
      const token = selectedToken.getState();
      const srcChain = connectedSourceChain.getState();
      const dest = destNetwork.getState();
      if (!token || !srcChain || !dest?.id) return;
      const type: TokenType = token.type;
      const walletClient = await getConnectedWallet(srcChain.id);

      const tokenAddress = token.addresses[srcChain.id];

      if (type === TokenType.ERC1155 || type === TokenType.ERC721) {
        const nfts = selectedNFTs.getState();
        const tokenIds = nfts && nfts.map((nft) => BigInt(nft.tokenId));

        const spenderAddress =
          type === TokenType.ERC1155
            ? routingContractsMap[srcChain.id][dest.id].erc1155VaultAddress
            : routingContractsMap[srcChain.id][dest.id].erc721VaultAddress;

        const args: NFTApproveArgs = {
          tokenIds: tokenIds!,
          tokenAddress,
          spenderAddress,
          wallet: walletClient,
        };
        approveTxHashRef.current = await (
          bridges[type] as ERC721Bridge | ERC1155Bridge
        ).approve(args);
      } else {
        const spenderAddress =
          routingContractsMap[srcChain.id][dest.id].erc20VaultAddress;

        const args: ApproveArgs = {
          tokenAddress,
          spenderAddress,
          wallet: walletClient,
          amount: enteredAmount.getState(),
        };
        approveTxHashRef.current = await (bridges[type] as ERC20Bridge).approve(
          args,
        );
      }

      if (approveTxHashRef.current)
        await handleApproveTxHash(approveTxHashRef.current);
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  async function bridge() {
    const service = bridgeService.getState();
    const token = selectedToken.getState();
    const srcChain = connectedSourceChain.getState();
    const dest = destNetwork.getState();
    const userAddress = account.getState()?.address;
    if (!service || !token || !srcChain || !dest?.id || !userAddress) return;
    setBridging(true);
    try {
      const walletClient = await getConnectedWallet(srcChain.id);
      const commonArgs = {
        to: recipientAddress.getState() || userAddress,
        wallet: walletClient,
        srcChainId: srcChain.id,
        destChainId: dest.id,
        fee: processingFee.getState(),
        tokenObject: token,
      };

      const type: TokenType = token.type;
      if (type === TokenType.ERC1155 || type === TokenType.ERC721) {
        const nfts = selectedNFTs.getState();
        const tokenIds = nfts && nfts.map((nft) => nft.tokenId);
        if (!tokenIds) throw new Error("tokenIds not found");
        const bridgeArgs = await getBridgeArgs(
          token,
          enteredAmount.getState(),
          commonArgs,
          tokenIds,
        );

        const args = { ...bridgeArgs, tokenIds, tokenObject: token };

        bridgeTxHashRef.current = await service.bridge(args);
      } else {
        const bridgeArgs = await getBridgeArgs(
          token,
          enteredAmount.getState(),
          commonArgs,
        );

        bridgeTxHashRef.current = await service.bridge(bridgeArgs);
      }

      if (bridgeTxHashRef.current) {
        await handleBridgeTxHash(bridgeTxHashRef.current);
      }
    } catch (err) {
      setBridging(false);
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  // onMount(() => (bridgingStatus = BridgingStatus.PENDING))
  useEffect(() => {
    setBridgingStatus(BridgingStatus.PENDING);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="mt-[30px]">
      <section id="txStatus">
        <div className="flex flex-col justify-content-center items-center">
          {bridgingStatus === BridgingStatus.DONE ? (
            <>
              <Icon type={icon} size={160} fillClass={iconFill} />
              <div id="text" className="f-col my-[30px] text-center">
                <h1 dangerouslySetInnerHTML={{ __html: statusTitle }} />
                <span
                  className=""
                  dangerouslySetInnerHTML={{ __html: statusDescription }}
                />
              </div>
            </>
          ) : !$allApproved && !approving && !checking ? (
            <>
              <Icon type={approveIcon} size={160} />
              <div id="text" className="f-col my-[30px] text-center">
                <h1 className="mb-[16px]">
                  {t("bridge.step.confirm.approve.title")}
                </h1>
                <span>{t("bridge.step.confirm.approve.description")}</span>
              </div>
            </>
          ) : checking ? (
            <>
              <Spinner className="!w-[160px] !h-[160px] text-primary-brand" />
              <div id="text" className="f-col my-[30px] text-center">
                <h1 className="mb-[16px]">
                  {t("bridge.step.confirm.analyzing")}
                </h1>
                <span>{t("bridge.step.confirm.checking_status")}</span>
              </div>
            </>
          ) : approving || bridging ? (
            <>
              <Spinner className="!w-[160px] !h-[160px] text-primary-brand" />
              <div id="text" className="f-col my-[30px] text-center">
                <h1 className="mb-[16px]">
                  {t("bridge.step.confirm.processing")}
                </h1>
                <span>{t("bridge.step.confirm.approve.pending")}</span>
              </div>
            </>
          ) : $allApproved && !approving && !bridging ? (
            <>
              <Icon type={bridgeIcon} size={160} />
              <div id="text" className="f-col my-[30px] text-center">
                <h1 className="mb-[16px]">
                  {t("bridge.step.confirm.approved.title")}
                </h1>
                {$selectedToken?.type === TokenType.ETH ? (
                  <span>
                    {t("bridge.step.confirm.approved.description_eth")}
                  </span>
                ) : (
                  <span>
                    {t("bridge.step.confirm.approved.description_token")}
                  </span>
                )}
              </div>
            </>
          ) : null}
        </div>
      </section>
      {bridgingStatus === BridgingStatus.PENDING && (
        <section id="actions" className="f-col w-full">
          <div className="h-sep mb-[30px]" />
          <Actions
            approve={approve}
            bridge={bridge}
            resetApproval={resetApproval}
            bridging={bridging}
            onBridgingChange={setBridging}
            approving={approving}
            onApprovingChange={setApproving}
            checking={checking}
            onCheckingChange={setChecking}
            resetting={resetting}
            onResettingChange={setResetting}
          />
        </section>
      )}
    </div>
  );
}
