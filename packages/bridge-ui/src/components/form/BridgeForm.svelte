<script lang="ts">
  import { _ } from "svelte-i18n";
  import { token } from "../../store/token";
  import { processingFee } from "../../store/fee";
  import { fromChain, toChain } from "../../store/chain";
  import {
    activeBridge,
    chainIdToBridgeAddress,
    bridgeType,
  } from "../../store/bridge";
  import { signer } from "../../store/signer";
  import { BigNumber, ethers, Signer } from "ethers";
  import ProcessingFee from "./ProcessingFee.svelte";
  import { ETH } from "../../domain/token";
  import SelectToken from "../buttons/SelectToken.svelte";

  import type { Token } from "../../domain/token";
  import type { BridgeType } from "../../domain/bridge";
  import type { Chain } from "../../domain/chain";
  import { truncateString } from "../../utils/truncateString";
  import { pendingTransactions } from "../../store/transactions";
  import { ProcessingFeeMethod } from "../../domain/fee";
  import Memo from "./Memo.svelte";
  import { errorToast, successToast } from "../../utils/toast";

  let amount: string;
  let requiresAllowance: boolean = true;
  let btnDisabled: boolean = true;
  let tokenBalance: string;
  let customFee: string = "0.01";
  let memo: string = "";

  $: getUserBalance($signer, $token);

  async function getUserBalance(signer, token) {
    if (signer && token) {
      if (token.symbol == ETH.symbol) {
        const userBalance = await signer.getBalance("latest");
        tokenBalance = ethers.utils.formatEther(userBalance);
      } else {
        // TODO: read ERC20 balance from contract
      }
    }
  }

  $: isBtnDisabled($signer, amount, $token, requiresAllowance)
    .then((d) => (btnDisabled = d))
    .catch((e) => console.log(e));

  $: checkAllowance(amount, $token, $bridgeType, $fromChain, $signer)
    .then((a) => (requiresAllowance = a))
    .catch((e) => console.log(e));

  async function checkAllowance(
    amt: string,
    token: Token,
    bridgeType: BridgeType,
    fromChain: Chain,
    signer: Signer
  ) {
    if (!fromChain || !amt || !token || !bridgeType || !signer) return true;

    const allowance = await $activeBridge.RequiresAllowance({
      amountInWei: amt
        ? ethers.utils.parseUnits(amt, token.decimals)
        : BigNumber.from(0),
      signer: signer,
      contractAddress: token.address,
      spenderAddress: $chainIdToBridgeAddress.get(fromChain.id),
    });
    return allowance;
  }

  async function isBtnDisabled(
    signer: Signer,
    amount: string,
    token: Token,
    requiresAllowance: boolean
  ) {
    if (!signer) return true;
    if (!amount) return true;
    if (requiresAllowance) return true;
    const balance = await signer.getBalance("latest");
    if (balance.lt(ethers.utils.parseUnits(amount, token.decimals)))
      return true;

    return false;
  }

  async function approve() {
    try {
      if (!requiresAllowance)
        throw Error("does not require additional allowance");

      const tx = await $activeBridge.Approve({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        contractAddress: $token.address,
        spenderAddress: $chainIdToBridgeAddress.get($fromChain.id),
      });

      console.log("approved, waiting for confirmations ", tx);

      await $signer.provider.waitForTransaction(tx.hash, 3);

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      requiresAllowance = false;
      successToast($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    }
  }

  async function bridge() {
    try {
      if (requiresAllowance) throw Error("requires additional allowance");

      const tx = await $activeBridge.Bridge({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        tokenAddress: "",
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        bridgeAddress: $chainIdToBridgeAddress.get($fromChain.id),
        processingFeeInWei: getProcessingFee(),
        memo: memo,
      });

      // tx.chainId is not set immediately but we need it later. set it
      // manually.
      tx.chainId = $fromChain.id;
      let transactions: ethers.Transaction[] = JSON.parse(
        await window.localStorage.getItem("transactions")
      );
      if (!transactions) {
        transactions = [tx];
      } else {
        transactions.push(tx);
      }

      await window.localStorage.setItem(
        "transactions",
        JSON.stringify(transactions)
      );

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_("toast.transactionSent"));
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    }
  }

  function useFullAmount() {
    amount = tokenBalance;
  }

  function updateAmount(e: any) {
    amount = (e.data as number).toString();
  }

  function getProcessingFee() {
    if ($processingFee === ProcessingFeeMethod.NONE) {
      return undefined;
    }

    if ($processingFee === ProcessingFeeMethod.CUSTOM) {
      return BigNumber.from(ethers.utils.parseEther(customFee));
    }

    if ($processingFee === ProcessingFeeMethod.RECOMMENDED) {
      return ethers.utils.parseEther("0.001");
    }
  }
</script>

<div class="form-control my-4 md:my-8">
  <label class="label" for="amount">
    <span class="label-text">{$_("bridgeForm.fieldLabel")}</span>
    {#if $signer && tokenBalance}
      <button class="label-text" on:click={useFullAmount}
        >{$_("bridgeForm.maxLabel")}
        {tokenBalance.length > 10
          ? `${truncateString(tokenBalance)}...`
          : tokenBalance} ETH</button
      >{/if}
  </label>
  <label
    class="input-group relative rounded-lg bg-dark-4 justify-between items-center pr-4"
  >
    <input
      type="number"
      step="0.01"
      placeholder="0.01"
      min="0"
      on:input={updateAmount}
      class="input input-primary bg-dark-4 input-md md:input-lg w-full"
      name="amount"
    />
    <SelectToken />
  </label>
</div>

<ProcessingFee bind:customFee />

<Memo bind:memo />

{#if !requiresAllowance}
  <button
    class="btn btn-accent w-full"
    on:click={bridge}
    disabled={btnDisabled}
  >
    {$_("home.bridge")}
  </button>
{:else}
  <button
    class="btn btn-accent w-full"
    on:click={approve}
    disabled={btnDisabled}
  >
    {$_("home.approve")}
  </button>
{/if}
