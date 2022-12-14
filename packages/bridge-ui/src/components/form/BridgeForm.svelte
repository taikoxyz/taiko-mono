<script lang="ts">
  import { _ } from "svelte-i18n";
  import { LottiePlayer } from "@lottiefiles/svelte-lottie-player";

  import { token } from "../../store/token";
  import { processingFee } from "../../store/fee";
  import { fromChain, toChain } from "../../store/chain";
  import {
    activeBridge,
    chainIdToTokenVaultAddress,
    bridgeType,
  } from "../../store/bridge";
  import { signer } from "../../store/signer";
  import { BigNumber, Contract, ethers, Signer } from "ethers";
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
  import ERC20 from "../../constants/abi/ERC20";

  let amount: string;
  let requiresAllowance: boolean = true;
  let btnDisabled: boolean = true;
  let tokenBalance: string;
  let customFee: string = "0.01";
  let memo: string = "";
  let loading: boolean = false;

  $: getUserBalance($signer, $token);

  async function getUserBalance(signer, token) {
    if (signer && token) {
      if (token.symbol == ETH.symbol) {
        const userBalance = await signer.getBalance("latest");
        tokenBalance = ethers.utils.formatEther(userBalance);
      } else {
        const contract = new Contract(token.address, ERC20, signer);
        const userBalance = await contract.balanceOf(await signer.getAddress());
        tokenBalance = ethers.utils.formatUnits(userBalance, token.decimals);
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
      contractAddress: token.addresses.find((t) => t.chainId === fromChain.id)
        .address,
      spenderAddress: $chainIdToTokenVaultAddress.get(fromChain.id),
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
    if (isNaN(parseFloat(amount))) return true;
    if (
      BigNumber.from(ethers.utils.parseUnits(tokenBalance, token.decimals)).lt(
        ethers.utils.parseUnits(amount, token.decimals)
      )
    )
      return true;

    return false;
  }

  async function approve() {
    try {
      loading = true;
      if (!requiresAllowance)
        throw Error("does not require additional allowance");

      const tx = await $activeBridge.Approve({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        contractAddress: $token.addresses.find(
          (t) => t.chainId === $fromChain.id
        ).address,
        spenderAddress: $chainIdToTokenVaultAddress.get($fromChain.id),
      });

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_("toast.transactionSent"));
      await $signer.provider.waitForTransaction(tx.hash, 1);

      requiresAllowance = false;
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    } finally {
      loading = false;
    }
  }

  async function bridge() {
    try {
      loading = true;
      if (requiresAllowance) throw Error("requires additional allowance");

      const tx = await $activeBridge.Bridge({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        tokenAddress: $token.addresses.find((t) => t.chainId === $fromChain.id)
          .address,
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        tokenVaultAddress: $chainIdToTokenVaultAddress.get($fromChain.id),
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
      await $signer.provider.waitForTransaction(tx.hash, 1);
    } catch (e) {
      console.log(e);
      errorToast($_("toast.errorSendingTransaction"));
    } finally {
      loading = false;
    }
  }

  function useFullAmount() {
    amount = tokenBalance;
  }

  function updateAmount(e: any) {
    amount = (e.target.value as number).toString();
  }

  function getProcessingFee() {
    if ($processingFee === ProcessingFeeMethod.NONE) {
      return undefined;
    }

    if ($processingFee === ProcessingFeeMethod.CUSTOM) {
      return BigNumber.from(ethers.utils.parseEther(customFee));
    }

    if ($processingFee === ProcessingFeeMethod.RECOMMENDED) {
      return ethers.utils.parseEther("0.01");
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
          : tokenBalance}
        {$token.symbol}
      </button>{/if}
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
{:else if loading}
  <button class="btn btn-accent w-full" disabled={true}>
    <LottiePlayer
      src="/lottie/loader.json"
      autoplay={true}
      loop={true}
      controls={false}
      renderer="svg"
      background="transparent"
      height={26}
      width={26}
      controlsLayout={[]}
    />
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
