"use client";

import { switchChain } from "@wagmi/core";
import { forwardRef, useImperativeHandle, useRef } from "react";
import type { Hash } from "viem";

import { bridges, type BridgeTransaction } from "@/libs/bridge";
import { NotConnectedError } from "@/libs/error";
import { getConnectedWallet } from "@/libs/util/getConnectedWallet";
import { getLogger } from "@/libs/util/logger";
import { config } from "@/libs/wagmi";
import { account } from "@/stores/account";
import { connectedSourceChain } from "@/stores/network";

import { selectedRetryMethod } from "./RetryDialog/state";
import { RETRY_OPTION } from "./RetryDialog/types";
import { ClaimAction } from "./Shared/types";

const log = getLogger("Claim");

/**
 * Imperative handle exposed to parents (Svelte `bind:this={ClaimComponent}`
 * calling `ClaimComponent.claim(...)`). Mirrors the original `export const claim`.
 */
export interface ClaimHandle {
  /** Svelte `export const claim`. */
  claim: (
    action: ClaimAction,
    force?: boolean,
    skipMessageStatusCheck?: boolean,
  ) => Promise<void>;
}

/** Detail payload of the original `dispatch('error', { error, action })`. */
export interface ClaimErrorDetail {
  error: unknown;
  action: ClaimAction;
}

/** Detail payload of the original `dispatch('claimingTxSent', { txHash, action })`. */
export interface ClaimTxSentDetail {
  txHash: Hash;
  action: ClaimAction;
}

export interface ClaimProps {
  /** Svelte `export let bridgeTx`. */
  bridgeTx: BridgeTransaction;
  /** dispatch('error', { error, action }). */
  onError?: (detail: ClaimErrorDetail) => void;
  /** dispatch('claimingTxSent', { txHash, action }). */
  onClaimingTxSent?: (detail: ClaimTxSentDetail) => void;
}

/**
 * React port of `components/Dialogs/Claim.svelte`.
 *
 * The source is a renderless component (no markup) that exposes an imperative
 * `claim()` method via `bind:this` and dispatches `error` / `claimingTxSent`
 * events. Here that becomes a `forwardRef` component returning `null`, exposing
 * `claim()` through `useImperativeHandle`, with the two dispatched events mapped
 * to `onError` / `onClaimingTxSent` callback props.
 *
 * The Svelte reactive store reads (`$account`, `$connectedSourceChain`,
 * `$selectedRetryMethod`) become imperative `.getState()` reads on the migrated
 * vanilla stores, evaluated at call-time exactly like the originals.
 */
const Claim = forwardRef<ClaimHandle, ClaimProps>(function Claim(
  { bridgeTx, onError, onClaimingTxSent },
  ref,
) {
  // Keep the latest props in refs so the imperative `claim()` always uses the
  // most recent values (mirroring Svelte's always-fresh reactive reads).
  const bridgeTxRef = useRef(bridgeTx);
  bridgeTxRef.current = bridgeTx;
  const onErrorRef = useRef(onError);
  onErrorRef.current = onError;
  const onClaimingTxSentRef = useRef(onClaimingTxSent);
  onClaimingTxSentRef.current = onClaimingTxSent;

  async function ensureCorrectChain(action: ClaimAction) {
    const sourceChain = connectedSourceChain.getState();
    const currentChainId = Number(sourceChain?.id);
    const tx = bridgeTxRef.current;
    const txDestChain = Number(tx.destChainId);
    const txSrcChain = Number(tx.srcChainId);

    let expectedChainId: number;

    if (action === ClaimAction.RELEASE) {
      // If we are releasing, we need to be on the source chain
      expectedChainId = txSrcChain;
    } else {
      expectedChainId = txDestChain;
    }

    const isCorrectChain = currentChainId === expectedChainId;

    log(`Are we on the correct chain? ${isCorrectChain}`);

    if (!isCorrectChain) {
      await switchChain(config, { chainId: expectedChainId });
    }
  }

  const claim = async (
    action: ClaimAction,
    force: boolean = false,
    skipMessageStatusCheck: boolean = false,
  ) => {
    const currentAccount = account.getState();
    if (!currentAccount?.address) {
      throw new NotConnectedError("User is not connected");
    }

    try {
      const tx = bridgeTxRef.current;
      const { msgHash, message } = tx;

      if (!msgHash || !message) {
        throw new Error("Missing msgHash or message");
      }

      // Step 1: make sure the user is on the correct chain
      await ensureCorrectChain(action);

      // Step 2: Find out the type of bridge: ETHBridge, ERC20Bridge, etc
      const bridge = bridges[tx.tokenType];

      // Step 3: get the user's wallet
      const wallet = await getConnectedWallet(Number(tx.destChainId));

      // Step 4: Call claim() method on the bridge
      let txHash: Hash;
      if (selectedRetryMethod.getState() === RETRY_OPTION.RETRY_ONCE) {
        log("Claiming with lastAttempt flag");
        txHash = await bridge.processMessage({
          wallet,
          bridgeTx: tx,
          lastAttempt: true,
        });
      } else {
        txHash = await bridge.processMessage(
          { wallet, bridgeTx: tx },
          force,
          skipMessageStatusCheck,
        );
      }

      onClaimingTxSentRef.current?.({ txHash, action });
    } catch (err) {
      onErrorRef.current?.({ error: err, action });
    }
  };

  useImperativeHandle(ref, () => ({ claim }));

  // Renderless component (the source had no markup).
  return null;
});

export default Claim;
