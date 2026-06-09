"use client";

// React port of src/components/Transactions/Transactions.svelte.
//
// COMPONENT CONVENTION mapping:
//   - No props on the original component (top-level feature view) -> no props here.
//   - Reactive `$:` derivations -> `useMemo`.
//   - Local `let` UI state (currentPage / isBlurred / loadingTxs / selectedStatus /
//     menuOpen / transactions) -> `useState`.
//   - Store reads:
//       `$account`            -> `useAccount(selector)` over the ported vanilla store.
//       `$activeBridge`       -> `useBridgeState(activeBridge)`.
//       `$destNetwork`        -> `useBridgeState(destNetwork)` (write via `destNetwork.setState`).
//       `$isDesktop/$isTablet`-> `useResponsive()` (libs/util/responsiveCheck breakpoints).
//   - `<DesktopOrLarger bind:is={isDesktopOrLarger} />` -> `useDesktopOrLarger()` hook.
//   - `<OnAccount change={onAccountChange} />` -> kept as the renderless component.
//   - `onMount` (destNetwork default) -> `useEffect(..., [])`.
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)`.
//   - `on:click` -> `onClick`; `on:click|stopPropagation` -> `onClick` calling
//     `e.stopPropagation()`.
//   - Paginator `on:pageChange={({ detail }) => handlePageChange(detail)}` ->
//     `onPageChange={handlePageChange}` (the migrated Paginator emits the raw page).
//   - `bind:selectedStatus` (StatusFilterDropdown) -> `selectedStatus` +
//     `onSelectedStatusChange`.
//   - `bind:selectedStatus` + `bind:menuOpen` (StatusFilterDialog) -> controlled
//     props + `onSelectedStatusChange` / `onMenuOpenChange`.
//   - Row `bind:bridgeTx` -> plain `bridgeTx` prop (the migrated Row owns its own
//     internal status state); `handleTransactionRemoved` forwarded as the
//     `(event: CustomEvent) => void` callback the migrated Row expects.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { Address } from "viem";

import {
  activeBridge,
  destNetwork,
  useBridgeState,
} from "@/components/Bridge/state";
import { BridgeTypes } from "@/components/Bridge/types";
import { Button } from "@/components/Button";
import { Card } from "@/components/Card";
import {
  ChainSelector,
  ChainSelectorDirection,
  ChainSelectorType,
} from "@/components/ChainSelectors";
import { useDesktopOrLarger } from "@/components/DesktopOrLarger";
import { Icon } from "@/components/Icon";
import RotatingIcon from "@/components/Icon/RotatingIcon";
import { warningToast } from "@/components/NotificationToast";
import { OnAccount } from "@/components/OnAccount";
import { Paginator } from "@/components/Paginator";
import { Spinner } from "@/components/Spinner";
import { StatusDot } from "@/components/StatusDot";
import { transactionConfig } from "@/app.config";
import {
  type BridgeTransaction,
  fetchTransactions,
  MessageStatus,
} from "@/libs/bridge";
import { chainIdToChain } from "@/libs/chain";
import { getAlternateNetwork } from "@/libs/network";
import { bridgeTxService } from "@/libs/storage";
import { TokenType } from "@/libs/token";
import { useResponsive } from "@/hooks/useResponsive";
import { useTranslation } from "@/i18n/useTranslation";
import { account, type Account, useAccount } from "@/stores/account";

import { StatusFilterDialog, StatusFilterDropdown } from "./Filter";
import { FungibleTransactionRow, NftTransactionRow } from "./Rows";
import { StatusInfoDialog } from "./Status";

export default function Transactions() {
  const { t } = useTranslation();

  const { isDesktop, isTablet } = useResponsive();
  const isDesktopOrLarger = useDesktopOrLarger();

  const $account = useAccount((a) => a);
  const $activeBridge = useBridgeState(activeBridge);

  const [transactions, setTransactions] = useState<BridgeTransaction[]>([]);
  const [currentPage, setCurrentPage] = useState(1);
  const [isBlurred, setIsBlurred] = useState(false);
  const transitionTime = transactionConfig.blurTransitionTime;
  const [loadingTxs, setLoadingTxs] = useState(false);
  const [selectedStatus, setSelectedStatus] = useState<MessageStatus | null>(
    null,
  ); // null indicates no filter is applied
  const [menuOpen, setMenuOpen] = useState(false);

  // Reentrancy guard mirroring the source's synchronous `if (loadingTxs) return;`
  // check at the top of `updateTransactions`. The ref is the authoritative guard
  // (set/cleared imperatively inside `updateTransactions`); `loadingTxs` state only
  // drives the UI. The ref is never read or written during render.
  const loadingTxsRef = useRef(false);

  const toggleMenu = () => {
    setMenuOpen((open) => !open);
  };

  const handlePageChange = (detail: number) => {
    setIsBlurred(true);
    setTimeout(() => {
      setCurrentPage(detail);
      setIsBlurred(false);
    }, transitionTime);
  };

  const getTransactionsToShow = (
    page: number,
    size: number,
    bridgeTx: BridgeTransaction[],
  ) => {
    const start = (page - 1) * size;
    const end = start + size;
    return bridgeTx.slice(start, end);
  };

  // Stable identity: depends only on `t` (and stable setters/refs), so it does
  // not change on account/responsive/filter re-renders. This lets the stable
  // `handleTransactionRemoved` callback below stay stable too.
  const updateTransactions = useCallback(
    async (address: Address) => {
      if (loadingTxsRef.current) return;
      loadingTxsRef.current = true;
      setLoadingTxs(true);
      const { mergedTransactions, outdatedLocalTransactions, error } =
        await fetchTransactions(address);
      setTransactions(mergedTransactions);

      if (outdatedLocalTransactions.length > 0) {
        await bridgeTxService.removeTransactions(
          address,
          outdatedLocalTransactions,
        );
      }
      if (error) {
        warningToast({ title: t("transactions.errors.relayer_offline") });
      }
      loadingTxsRef.current = false;
      setLoadingTxs(false);
    },
    [t],
  );

  const refresh = async () => {
    if ($account?.address) {
      await updateTransactions($account.address);
    }
  };

  const onAccountChange = async (
    newAccount: Account | undefined,
    oldAccount?: Account,
  ) => {
    // We want to make sure that we are connected and only
    // fetch if the account has changed
    if (
      newAccount?.isConnected &&
      newAccount.address &&
      newAccount.address !== oldAccount?.address
    ) {
      await updateTransactions(newAccount.address);
    }
  };

  // `handleTransactionRemoved` is passed to every (memoized) transaction row, so
  // keep its identity stable. It reads the latest connected address from the
  // vanilla account store at call time — behavior is identical to `refresh()`
  // (only invoked from a row's async removal event, never during render).
  const handleTransactionRemoved = useCallback(() => {
    const address = account.getState()?.address;
    if (address) void updateTransactions(address);
  }, [updateTransactions]);

  // refresh only if previous account is different from current account
  // ($: { if (($account && previousAccount && ...) || !previousAccount) { refresh(); previousAccount = $account; } })
  const previousAccountRef = useRef<Account | null>(null);
  useEffect(() => {
    const previousAccount = previousAccountRef.current;
    if (
      ($account &&
        previousAccount &&
        $account.address !== previousAccount.address) ||
      !previousAccount
    ) {
      refresh();
      previousAccountRef.current = $account ?? null;
    }
  }, [$account]); // eslint-disable-line react-hooks/exhaustive-deps

  const fungibleView = $activeBridge === BridgeTypes.FUNGIBLE;
  const nftView = $activeBridge === BridgeTypes.NFT;

  const fungibleTokens = useMemo(() => [TokenType.ERC20, TokenType.ETH], []);
  const nftTokens = useMemo(() => [TokenType.ERC721, TokenType.ERC1155], []);
  const allTokens = useMemo(
    () => [...fungibleTokens, ...nftTokens],
    [fungibleTokens, nftTokens],
  );

  const displayTokenTypesBasedOnType = useMemo(
    () => (fungibleView ? fungibleTokens : nftView ? nftTokens : allTokens),
    [fungibleView, nftView, fungibleTokens, nftTokens, allTokens],
  );

  const statusFilteredTransactions = useMemo(
    () =>
      selectedStatus !== null
        ? transactions.filter((tx) => tx.msgStatus === selectedStatus)
        : transactions,
    [selectedStatus, transactions],
  );

  const tokenAndStatusFilteredTransactions = useMemo(
    () =>
      statusFilteredTransactions.filter((tx) =>
        displayTokenTypesBasedOnType.includes(tx.tokenType),
      ),
    [statusFilteredTransactions, displayTokenTypesBasedOnType],
  );

  const filteredTransactions = useMemo(
    () =>
      transactions.filter((tx) =>
        displayTokenTypesBasedOnType.includes(tx.tokenType),
      ),
    [transactions, displayTokenTypesBasedOnType],
  );

  const pageSize = isDesktopOrLarger
    ? transactionConfig.pageSizeDesktop
    : transactionConfig.pageSizeMobile;

  const transactionsToShow = useMemo(
    () =>
      getTransactionsToShow(
        currentPage,
        pageSize,
        tokenAndStatusFilteredTransactions,
      ),
    [currentPage, pageSize, tokenAndStatusFilteredTransactions],
  );

  const totalItems = filteredTransactions.length;

  // Some shortcuts to make the code more readable
  const isConnected = $account?.isConnected;
  const hasTxs = filteredTransactions.length > 0;

  // Controls what we render on the page
  const renderLoading = loadingTxs && isConnected;
  const renderTransactions = !renderLoading && isConnected && hasTxs;
  const renderNoTransactions =
    !renderLoading && transactionsToShow.length === 0;

  useEffect(() => {
    const alternateChainID = getAlternateNetwork();
    if (!destNetwork.getState() && alternateChainID) {
      // if only two chains are available, set the destination chain to the other one
      destNetwork.setState(chainIdToChain(alternateChainID));
    }
  }, []);

  return (
    <>
      <div className="flex flex-col justify-center w-full">
        <Card
          title={t("transactions.title")}
          text={t("transactions.description")}
        >
          <div className="space-y-[35px]">
            {isDesktop ? (
              <div className="my-[30px] f-between-center max-h-[36px] gap-2">
                <ChainSelector
                  type={ChainSelectorType.SMALL}
                  direction={ChainSelectorDirection.SOURCE}
                  label={t("chain_selector.currently_on")}
                  switchWallet
                />
                <div className="flex gap-2">
                  <Button
                    type="neutral"
                    shape="circle"
                    className="bg-neutral rounded-full !min-w-[36px] !min-h-[36px] !max-w-[36px] !max-h-[36px] border-none"
                    onClick={async () => await refresh()}
                  >
                    <RotatingIcon
                      loading={loadingTxs}
                      type="refresh"
                      size={16}
                    />
                  </Button>
                  <StatusFilterDropdown
                    selectedStatus={selectedStatus}
                    onSelectedStatusChange={setSelectedStatus}
                  />
                </div>
              </div>
            ) : (
              <div className="f-row justify-between my-[30px]">
                <div className="f-row items-center gap-[10px]">
                  <StatusDot type="success" simple={false} />
                  <ChainSelector
                    type={ChainSelectorType.SMALL}
                    direction={ChainSelectorDirection.SOURCE}
                    switchWallet
                  />
                </div>
                <div className="f-row items-center gap-[5px]">
                  {$account && $account?.address ? (
                    <>
                      <button
                        className="grid place-items-center bg-neutral min-w-[36px] max-w-[36px] min-h-[36px] max-h-[36px] rounded-full"
                        onClick={(e) => {
                          e.stopPropagation();
                          toggleMenu();
                        }}
                      >
                        <Icon
                          type="settings"
                          fillClass="fill-primary-icon"
                          size={18}
                          className="self-center"
                        />
                      </button>
                      <Button
                        type="neutral"
                        shape="circle"
                        className="bg-neutral rounded-full !min-w-[36px] !min-h-[36px] !max-w-[36px] !max-h-[36px] border-none"
                        onClick={async () => await refresh()}
                      >
                        <RotatingIcon
                          loading={loadingTxs}
                          type="refresh"
                          size={16}
                        />
                      </Button>
                    </>
                  ) : null}
                </div>
              </div>
            )}

            <div
              className="flex flex-col"
              style={{
                minHeight: `calc(${transactionsToShow.length} * ${isDesktopOrLarger ? "80px" : "66px"})`,
              }}
            >
              <div className="h-sep !mb-0 display-inline" />

              <div className="text-primary-content flex text-primary-content w-full my-[5px] md:my-[0px] px-[14px] py-[10px]">
                {$activeBridge === BridgeTypes.FUNGIBLE ? (
                  isDesktop ? (
                    <>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.from")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.to")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.amount")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content flex flex-row">
                        {t("transactions.header.status")}
                        <StatusInfoDialog />
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.date")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content"></div>
                    </>
                  ) : isTablet ? (
                    <>
                      <div className="w-1/4 py-2 text-secondary-content">
                        {t("transactions.header.from")}
                      </div>
                      <div className="w-1/4 py-2 text-secondary-content">
                        {t("transactions.header.to")}
                      </div>
                      <div className="w-1/4 py-2 text-secondary-content">
                        {t("transactions.header.amount")}
                      </div>
                      <div className="w-1/4 py-2 text-secondary-content flex flex-row">
                        {t("transactions.header.status")}
                        <StatusInfoDialog />
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="w-1/3 text-left pl-[11px] text-secondary-content">
                        {t("transactions.header.details")}
                      </div>
                      <div className="w-1/3 text-center text-secondary-content">
                        {t("transactions.header.amount")}
                      </div>
                      <div className="w-1/3 pr-[14px] f-row items-center justify-end text-secondary-content">
                        {t("transactions.header.status")}
                        <StatusInfoDialog />
                      </div>
                    </>
                  )
                ) : $activeBridge === BridgeTypes.NFT ? (
                  isDesktop ? (
                    <>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.nft")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.from")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.to")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content flex flex-row">
                        {t("transactions.header.status")}
                        <StatusInfoDialog />
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content">
                        {t("transactions.header.date")}
                      </div>
                      <div className="w-1/6 py-2 text-secondary-content"></div>
                    </>
                  ) : isTablet ? (
                    <>
                      <div className="w-1/4 py-2 text-secondary-content">
                        {t("transactions.header.nft")}
                      </div>
                      <div className="w-1/4 py-2 text-secondary-content">
                        {t("transactions.header.from")}
                      </div>
                      <div className="w-1/4 py-2 text-secondary-content">
                        {t("transactions.header.to")}
                      </div>

                      <div className="w-1/4 py-2 text-secondary-content flex flex-row">
                        {t("transactions.header.status")}
                        <StatusInfoDialog />
                      </div>
                    </>
                  ) : (
                    <>
                      <div className="w-1/3 text-left pl-[11px] text-secondary-content">
                        {t("transactions.header.details")}
                      </div>
                      <div className="w-1/3 text-center text-secondary-content">
                        {t("transactions.header.nft")}
                      </div>
                      <div className="w-1/3 pr-[14px] f-row items-center justify-end text-secondary-content">
                        {t("transactions.header.status")}
                        <StatusInfoDialog />
                      </div>
                    </>
                  )
                ) : null}
              </div>
              <div className="h-sep !my-0" />

              {renderLoading ? (
                <div className="flex items-center justify-center text-primary-content h-[80px]">
                  <Spinner />{" "}
                  <span className="pl-3">{t("common.loading")}...</span>
                </div>
              ) : null}

              {renderTransactions ? (
                <div
                  className="flex flex-col items-center"
                  style={
                    isBlurred
                      ? {
                          filter: "blur(5px)",
                          transition: `filter ${transitionTime / 1000}s ease-in-out`,
                        }
                      : undefined
                  }
                >
                  {transactionsToShow.map((bridgeTx) => {
                    const status = bridgeTx.msgStatus;
                    const isFungible =
                      bridgeTx.tokenType === TokenType.ERC20 ||
                      bridgeTx.tokenType === TokenType.ETH;
                    return (
                      <div key={bridgeTx.srcTxHash} className="contents">
                        {isFungible ? (
                          <FungibleTransactionRow
                            bridgeTx={bridgeTx}
                            handleTransactionRemoved={handleTransactionRemoved}
                            bridgeTxStatus={status}
                          />
                        ) : (
                          <NftTransactionRow
                            bridgeTx={bridgeTx}
                            handleTransactionRemoved={handleTransactionRemoved}
                            bridgeTxStatus={status}
                          />
                        )}
                        <div className="h-sep !my-0 display-inline" />
                      </div>
                    );
                  })}
                </div>
              ) : null}

              {renderNoTransactions ? (
                <div className="flex items-center justify-center text-primary-content h-[80px]">
                  <span className="pl-3">
                    {t("transactions.no_transactions")}
                  </span>
                </div>
              ) : null}
            </div>
          </div>
        </Card>

        <div className="flex justify-center lg:justify-end pb-5">
          <Paginator
            pageSize={pageSize}
            totalItems={totalItems}
            onPageChange={handlePageChange}
          />
        </div>

        <StatusFilterDialog
          selectedStatus={selectedStatus}
          onSelectedStatusChange={setSelectedStatus}
          menuOpen={menuOpen}
          onMenuOpenChange={setMenuOpen}
        />
      </div>

      <OnAccount change={onAccountChange} />
    </>
  );
}
