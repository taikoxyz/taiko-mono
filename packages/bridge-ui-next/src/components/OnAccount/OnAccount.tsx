"use client";

// Ported from src/components/OnAccount/OnAccount.svelte.
//
// Headless component: renders nothing (the original .svelte had an empty
// template). It subscribes to the `account` store and invokes the `change`
// callback whenever the account changes, passing the new account and the
// previously-seen account.
//
// PARITY NOTE: Svelte's `account.subscribe(cb)` fires the callback SYNCHRONOUSLY
// once on subscription with the store's current value. Zustand's vanilla
// `subscribe` does NOT — it only fires on subsequent changes. To preserve the
// original behaviour, we fire `change(currentAccount, undefined)` once on mount
// before wiring up the subscription, so consumers that diff `(newAccount,
// oldAccount)` (e.g. TokenDropdown's reset-on-account-change) behave identically.

import { useEffect, useRef } from "react";

import { type Account, account } from "@/stores/account";
import { noop } from "@/libs/util/noop";

export interface OnAccountProps {
  change?: (newAccount: Account | undefined, oldAccount?: Account) => void;
}

export default function OnAccount({ change = noop }: OnAccountProps) {
  // Keep the latest `change` callback in a ref so the subscription effect can
  // stay mounted for the component's lifetime without re-subscribing whenever
  // the parent passes a new inline callback.
  const changeRef = useRef(change);
  changeRef.current = change;

  useEffect(() => {
    let prevAccount: Account | undefined;

    // Mirror svelte's immediate-fire-on-subscribe contract.
    const current = account.getState();
    changeRef.current(current, prevAccount);
    prevAccount = current;

    const unsubscribe = account.subscribe((newAccount) => {
      changeRef.current(newAccount, prevAccount);
      prevAccount = newAccount;
    });

    return unsubscribe;
  }, []);

  return null;
}
