"use client";

// Ported from src/components/AccountConnectionToast/AccountConnectionToast.svelte.
//
// Headless component: renders an <OnAccount /> that watches the account store and
// fires `onAccountChange` whenever the account changes, surfacing connect /
// account-switch / chain-switch / disconnect toasts. The original used
// svelte-i18n's reactive `$t`; here we use the React `useTranslation` hook and
// keep the callback in sync via a ref so OnAccount can stay subscribed for its
// whole lifetime without re-wiring on every render.

import { useCallback } from "react";

import { OnAccount } from "@/components/OnAccount";
import { successToast, warningToast } from "@/components/NotificationToast";
import type { Account } from "@/stores/account";
import { useTranslation } from "@/i18n/useTranslation";

export default function AccountConnectionToast() {
  const { t } = useTranslation();

  // Listen to changes in the account state and notify the user
  // when the account is connected or disconnected via toast
  const onAccountChange = useCallback(
    (newAccount: Account | undefined, oldAccount?: Account) => {
      if (newAccount?.isConnected) {
        if (newAccount.chain === oldAccount?.chain) {
          // if the chain stays the same, we switched accounts
          successToast({ title: t("messages.account.connected") });
        } else {
          // otherwise we switched chains
          successToast({
            title: t("messages.network.success.title"),
            message: t("messages.network.success.message", {
              chainName: newAccount.chain?.name,
            }),
          });
        }
      } else if (oldAccount && newAccount?.isDisconnected) {
        // We check if there was previous account, if not
        // the user just hit the app, and there is no need
        // to show the message.
        warningToast({ title: t("messages.account.disconnected") });
      }
    },
    [t],
  );

  return <OnAccount change={onAccountChange} />;
}
