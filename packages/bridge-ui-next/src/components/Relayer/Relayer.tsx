"use client";

// React port of src/components/Relayer/Relayer.svelte.
//
// COMPONENT CONVENTION mapping:
//   - svelte-i18n `$t(key)` -> react-i18next `t(key)` via `@/i18n/useTranslation`.
//   - Local `let transactions / fetching / addressState` -> useState.
//   - Reactive `$:` blocks (`inputDisabled`, `searchDisabled`, `transactionsToShow`)
//     -> useMemo. `$: addressToSearch = undefined` is a one-time reactive init in
//     svelte; here `addressToSearch` is plain state seeded to `undefined`.
//   - `bind:ethereumAddress={addressToSearch}` -> controlled `ethereumAddress` +
//     `onEthereumAddressChange`. `bind:state={addressState}` -> `state` +
//     `onStateChange`.
//   - `<ActionButton on:click={fetchTxForAddress} ...>` -> `onClick`.
//   - `<OnAccount change={onAccountChange} />` -> ported headless OnAccount unit.
//   - `$account` store -> `useAccount` selector hook over the vanilla account store.
//   - `handleTransactionRemoved(event: CustomEvent<{ transaction }>)` preserved
//     verbatim (reads `event.detail.transaction`), matching the original source.
//
// DOM / Tailwind class strings preserved verbatim for pixel parity.

import { Fragment, useCallback, useMemo, useState } from "react";

import AddressInput from "@/components/Bridge/SharedBridgeComponents/AddressInput/AddressInput";
import { AddressInputState } from "@/components/Bridge/SharedBridgeComponents/AddressInput/state";
import ActionButton from "@/components/Button/ActionButton";
import Card from "@/components/Card/Card";
import OnAccount from "@/components/OnAccount/OnAccount";
import {
  FungibleTransactionRow,
  NftTransactionRow,
} from "@/components/Transactions/Rows";
import {
  type BridgeTransaction,
  fetchTransactions,
  MessageStatus,
} from "@/libs/bridge";
import { TokenType } from "@/libs/token";
import { getLogger } from "@/libs/util/logger";
import { type Account, useAccount } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

const log = getLogger("RelayerComponent");

export default function Relayer() {
  const { t } = useTranslation();

  const account = useAccount((a) => a);

  const [transactions, setTransactions] = useState<BridgeTransaction[]>([]);
  const [fetching, setFetching] = useState(false);
  const [addressState, setAddressState] = useState(AddressInputState.DEFAULT);
  const [addressToSearch, setAddressToSearch] = useState<string | undefined>(
    undefined,
  );

  const reset = useCallback(() => {
    log("reset");
    setTransactions([]);
    setFetching(false);
    setAddressState(AddressInputState.DEFAULT);
    setAddressToSearch(undefined);
  }, []);

  const onAccountChange = useCallback(
    async (newAccount: Account | undefined, oldAccount?: Account) => {
      // We want to make sure that we are connected and only
      // fetch if the account has changed
      if (
        newAccount &&
        newAccount.address &&
        newAccount.address !== oldAccount?.address
      ) {
        reset();
      }
    },
    [reset],
  );

  const fetchTxForAddress = useCallback(async () => {
    log("fetchTxForAddress");
    setFetching(true);
    if (addressToSearch) {
      const { mergedTransactions } = await fetchTransactions(
        addressToSearch as `0x${string}`,
      );
      log("mergedTransactions", mergedTransactions);
      if (mergedTransactions.length > 0) {
        setTransactions(mergedTransactions);
      }
    }
    setFetching(false);
  }, [addressToSearch]);

  const handleTransactionRemoved = useCallback(
    (event: CustomEvent<{ transaction: BridgeTransaction }>) => {
      log("handleTransactionRemoved", event.detail.transaction);
      setTransactions((prev) =>
        prev.filter((tx) => tx !== event.detail.transaction),
      );
    },
    [],
  );

  const inputDisabled = fetching || !account?.isConnected;

  const searchDisabled =
    fetching ||
    !addressToSearch ||
    addressState !== AddressInputState.VALID ||
    inputDisabled;

  const transactionsToShow = useMemo(
    () =>
      transactions.filter((tx) => {
        const gasLimitZero = tx.message?.gasLimit === 0;
        const userIsRecipientOrDestOwner =
          tx.message?.to === account?.address ||
          tx.message?.destOwner === account?.address;
        if (
          tx.status === MessageStatus.NEW ||
          tx.status === MessageStatus.RETRIABLE
        ) {
          if (gasLimitZero) {
            if (userIsRecipientOrDestOwner) {
              return tx;
            } else {
              console.warn(
                "gaslimit set to zero, not claimable by connected wallet",
                tx,
              );
            }
          } else {
            return tx;
          }
        }
      }),
    [transactions, account?.address],
  );

  return (
    <>
      <Card
        title={t("relayer_component.title")}
        className="container f-col md:w-[768px]"
        text={t("relayer_component.description")}
      >
        <div className="f-col space-y-[35px]">
          <span className="mt-[30px]">
            {t("relayer_component.step1.title")}
          </span>

          <AddressInput
            labelText={t("relayer_component.address_input_label")}
            isDisabled={inputDisabled}
            ethereumAddress={addressToSearch ?? ""}
            onEthereumAddressChange={(value) =>
              setAddressToSearch(value || undefined)
            }
            state={addressState}
            onStateChange={setAddressState}
          />

          <div className="h-sep" />
          <span>{t("relayer_component.step2.title")}</span>
          {/* NOTE: the source passed `label="Search"`, but ActionButton.svelte
              neither declared nor forwarded a `label` prop, so it was a no-op /
              dead prop. It is intentionally dropped here to preserve the rendered
              output exactly (the visible text is the slot/children below). */}
          <ActionButton
            onClick={fetchTxForAddress}
            priority="primary"
            className="w-full"
            loading={fetching}
            disabled={searchDisabled}
          >
            Search transactions
          </ActionButton>
          {transactionsToShow.length === 0 ? (
            <div className="text-center">
              {t("relayer_component.no_tx_found")}
            </div>
          ) : (
            <div className="h-sep" />
          )}
        </div>

        {transactionsToShow.map((bridgeTx) => {
          const status = bridgeTx.msgStatus;
          const isFungible =
            bridgeTx.tokenType === TokenType.ERC20 ||
            bridgeTx.tokenType === TokenType.ETH;
          return (
            <Fragment key={bridgeTx.srcTxHash}>
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
            </Fragment>
          );
        })}
      </Card>

      <OnAccount change={onAccountChange} />
    </>
  );
}
