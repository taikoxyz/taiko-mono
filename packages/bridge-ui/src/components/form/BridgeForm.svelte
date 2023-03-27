<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { LottiePlayer } from '@lottiefiles/svelte-lottie-player';

  import { token } from '../../store/token';
  import { processingFee } from '../../store/fee';
  import { fromChain, toChain } from '../../store/chain';
  import { activeBridge, bridgeType } from '../../store/bridge';
  import { signer } from '../../store/signer';
  import { BigNumber, Contract, ethers, Signer } from 'ethers';
  import ProcessingFee from './ProcessingFee.svelte';
  import SelectToken from '../buttons/SelectToken.svelte';

  import type { Token } from '../../domain/token';
  import type { BridgeOpts, BridgeType } from '../../domain/bridge';

  import type { Chain } from '../../domain/chain';
  import { truncateString } from '../../utils/truncateString';
  import {
    pendingTransactions,
    transactioner,
    transactions as transactionsStore,
  } from '../../store/transactions';
  import { ProcessingFeeMethod } from '../../domain/fee';
  import Memo from './Memo.svelte';
  import ERC20_ABI from '../../constants/abi/ERC20';
  import TokenVaultABI from '../../constants/abi/TokenVault';
  import type { BridgeTransaction } from '../../domain/transactions';
  import { MessageStatus } from '../../domain/message';
  import { Funnel } from 'svelte-heros-v2';
  import FaucetModal from '../modals/FaucetModal.svelte';
  import { errorToast, successToast } from '../Toast.svelte';
  import { L1_CHAIN_ID } from '../../constants/envVars';
  import { fetchFeeData } from '@wagmi/core';
  import { checkIfTokenIsDeployedCrossChain } from '../../utils/checkIfTokenIsDeployedCrossChain';
  import To from './To.svelte';
  import { ETHToken } from '../../token/tokens';
  import { chains } from '../../chain/chains';
  import { providers } from '../../provider/providers';
  import { tokenVaults } from '../../vault/tokenVaults';
  import { isOnCorrectChain } from '../../utils/isOnCorrectChain';

  let amount: string;
  let amountInput: HTMLInputElement;
  let requiresAllowance: boolean = false;
  let btnDisabled: boolean = true;
  let tokenBalance: string;
  let customFee: string = '0';
  let recommendedFee: string = '0';
  let memo: string = '';
  let loading: boolean = false;
  let isFaucetModalOpen: boolean = false;
  let memoError: string;
  let to: string = '';
  let showTo: boolean = false;

  // TODO: too much going on here. We need to extract
  //       logic and unit test the hell out of all this.

  async function addrForToken() {
    let addr = $token.addresses.find(
      (t) => t.chainId === $fromChain.id,
    ).address;
    if ($token.symbol !== ETHToken.symbol && (!addr || addr === '0x00')) {
      const srcChainAddr = $token.addresses.find(
        (t) => t.chainId === $toChain.id,
      ).address;

      const tokenVault = new Contract(
        tokenVaults[$fromChain.id],
        TokenVaultABI,
        $signer,
      );

      const bridged = await tokenVault.canonicalToBridged(
        $toChain.id,
        srcChainAddr,
      );

      addr = bridged;
    }
    return addr;
  }

  async function getUserBalance(
    signer: ethers.Signer,
    token: Token,
    fromChain: Chain,
  ) {
    if (signer && token) {
      if (token.symbol == ETHToken.symbol) {
        const userBalance = await signer.getBalance('latest');
        tokenBalance = ethers.utils.formatEther(userBalance);
      } else {
        const addr = await addrForToken();
        if (addr == ethers.constants.AddressZero) {
          tokenBalance = '0';
          return;
        }
        const contract = new Contract(addr, ERC20_ABI, signer);
        const userBalance = await contract.balanceOf(await signer.getAddress());
        tokenBalance = ethers.utils.formatUnits(userBalance, token.decimals);
      }
    }
  }

  async function checkAllowance(
    amt: string,
    token: Token,
    bridgeType: BridgeType,
    fromChain: Chain,
    signer: Signer,
  ) {
    if (!fromChain || !amt || !token || !bridgeType || !signer) return false;

    const addr = await addrForToken();
    const allowance = await $activeBridge.RequiresAllowance({
      amountInWei: ethers.utils.parseUnits(amt, token.decimals),
      signer: signer,
      contractAddress: addr,
      spenderAddress: tokenVaults[fromChain.id],
    });
    return allowance;
  }

  async function isBtnDisabled(
    signer: Signer,
    amount: string,
    token: Token,
    tokenBalance: string,
    requiresAllowance: boolean,
    memoError: string,
    fromChain: Chain,
  ) {
    if (!signer) return true;
    if (!tokenBalance) return true;
    if (!fromChain) return true;
    const chainId = fromChain.id;

    if (!chainId || !chains[chainId.toString()]) return true;

    if (!(await isOnCorrectChain(signer, fromChain.id))) return true;

    if (!amount || ethers.utils.parseUnits(amount).eq(BigNumber.from(0)))
      return true;
    if (isNaN(parseFloat(amount))) return true;

    if (
      BigNumber.from(ethers.utils.parseUnits(tokenBalance, token.decimals)).lt(
        ethers.utils.parseUnits(amount, token.decimals),
      )
    )
      return true;
    if (memoError) {
      return true;
    }

    return false;
  }

  async function approve() {
    try {
      loading = true;
      if (!requiresAllowance)
        throw Error('does not require additional allowance');

      const tx = await $activeBridge.Approve({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        contractAddress: await addrForToken(),
        spenderAddress: tokenVaults[$fromChain.id],
      });

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_('toast.transactionSent'));
      await $signer.provider.waitForTransaction(tx.hash, 1);

      requiresAllowance = false;
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  async function checkUserHasEnoughBalance(
    bridgeOpts: BridgeOpts,
  ): Promise<boolean> {
    try {
      const gasEstimate = await $activeBridge.EstimateGas({
        ...bridgeOpts,
        amountInWei: BigNumber.from(1),
      });
      const feeData = await fetchFeeData();
      const requiredGas = gasEstimate.mul(feeData.gasPrice);
      const userBalance = await $signer.getBalance('latest');

      let balanceAvailableForTx = userBalance;

      if ($token.symbol === ETHToken.symbol) {
        balanceAvailableForTx = userBalance.sub(
          ethers.utils.parseEther(amount),
        );
      }

      return balanceAvailableForTx.gte(requiredGas);
    } catch (e) {
      return false;
    }
  }

  async function bridge() {
    try {
      loading = true;
      if (requiresAllowance) throw Error('requires additional allowance');
      if (showTo && !ethers.utils.isAddress(to)) {
        throw Error('Invalid custom recipient address');
      }

      if (!(await isOnCorrectChain($signer, $fromChain.id))) {
        errorToast('You are connected to the wrong chain in your wallet');
        return;
      }

      const amountInWei = ethers.utils.parseUnits(amount, $token.decimals);

      const provider = providers[$toChain.id];
      const destTokenVaultAddress = tokenVaults[$toChain.id];
      let isBridgedTokenAlreadyDeployed =
        await checkIfTokenIsDeployedCrossChain(
          $token,
          provider,
          destTokenVaultAddress,
          $toChain,
          $fromChain,
        );

      const bridgeAddress = chains[$fromChain.id].bridgeAddress;
      const tokenVaultAddress = tokenVaults[$fromChain.id];

      const bridgeOpts: BridgeOpts = {
        amountInWei: amountInWei,
        signer: $signer,
        tokenAddress: await addrForToken(),
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        tokenVaultAddress: tokenVaultAddress,
        bridgeAddress: bridgeAddress,
        processingFeeInWei: getProcessingFee(),
        memo: memo,
        isBridgedTokenAlreadyDeployed,
        to: showTo && to ? to : await $signer.getAddress(),
      };

      const doesUserHaveEnoughBalance = await checkUserHasEnoughBalance(
        bridgeOpts,
      );

      if (!doesUserHaveEnoughBalance) {
        errorToast('Insufficient ETH balance');
        return;
      }

      const tx = await $activeBridge.Bridge(bridgeOpts);

      // tx.chainId is not set immediately but we need it later. set it
      // manually.
      tx.chainId = $fromChain.id;
      const userAddress = await $signer.getAddress();
      let transactions: BridgeTransaction[] =
        await $transactioner.getAllByAddress(userAddress);

      let bridgeTransaction: BridgeTransaction = {
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        symbol: $token.symbol,
        amountInWei: amountInWei,
        from: tx.from,
        hash: tx.hash,
        status: MessageStatus.New,
      };
      if (!transactions) {
        transactions = [bridgeTransaction];
      } else {
        transactions.push(bridgeTransaction);
      }

      $transactioner.updateStorageByAddress(userAddress, transactions);

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      const allTransactions = $transactionsStore;

      // get full BridgeTransaction object
      bridgeTransaction = await $transactioner.getTransactionByHash(
        userAddress,
        tx.hash,
      );

      transactionsStore.set([bridgeTransaction, ...allTransactions]);

      successToast($_('toast.transactionSent'));
      await $signer.provider.waitForTransaction(tx.hash, 1);
      memo = '';
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  async function useFullAmount() {
    if ($token.symbol === ETHToken.symbol) {
      try {
        const feeData = await fetchFeeData();
        const gasEstimate = await $activeBridge.EstimateGas({
          amountInWei: BigNumber.from(1),
          signer: $signer,
          tokenAddress: await addrForToken(),
          fromChainId: $fromChain.id,
          toChainId: $toChain.id,
          tokenVaultAddress: tokenVaults[$fromChain.id],
          processingFeeInWei: getProcessingFee(),
          memo: memo,
          to: showTo && to ? to : await $signer.getAddress(),
        });
        const requiredGas = gasEstimate.mul(feeData.gasPrice);
        const userBalance = await $signer.getBalance('latest');
        const processingFee = getProcessingFee();
        let balanceAvailableForTx = userBalance.sub(requiredGas);
        if (processingFee) {
          balanceAvailableForTx = balanceAvailableForTx.sub(processingFee);
        }

        amount = ethers.utils.formatEther(balanceAvailableForTx);
        amountInput.value = ethers.utils.formatEther(balanceAvailableForTx);
      } catch (error) {
        console.error(error);

        // In case of error default to using the full amount of ETH available.
        // The user would still not be able to make the restriction and will have to manually set the amount.
        amount = tokenBalance;
        amountInput.value = tokenBalance.toString();
      }
    } else {
      amount = tokenBalance;
      amountInput.value = tokenBalance.toString();
    }
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
      return BigNumber.from(ethers.utils.parseEther(recommendedFee));
    }
  }

  $: getUserBalance($signer, $token, $fromChain);

  $: isBtnDisabled(
    $signer,
    amount,
    $token,
    tokenBalance,
    requiresAllowance,
    memoError,
    $fromChain,
  )
    .then((d) => (btnDisabled = d))
    .catch((e) => console.error(e));

  $: checkAllowance(amount, $token, $bridgeType, $fromChain, $signer)
    .then((a) => (requiresAllowance = a))
    .catch((e) => console.error(e));

  // TODO: we need to simplify this crazy condition
  $: showFaucet =
    $fromChain && // chain selected?
    $fromChain.id === L1_CHAIN_ID && // are we in L1?
    $token.symbol !== ETHToken.symbol && // bridging ERC20?
    $signer && // wallet connected?
    tokenBalance &&
    ethers.utils
      .parseUnits(tokenBalance, $token.decimals)
      .eq(BigNumber.from(0)); // balance == 0?
</script>

<div class="form-control my-4 md:my-8">
  <label class="label" for="amount">
    <span class="label-text">{$_('bridgeForm.fieldLabel')}</span>

    {#if $signer && tokenBalance}
      <div class="label-text ">
        <span>
          {$_('bridgeForm.balance')}:
          {tokenBalance.length > 10
            ? `${truncateString(tokenBalance, 6)}...`
            : tokenBalance}
          {$token.symbol}
        </span>

        <button
          class="btn btn-xs rounded-md hover:border-accent text-xs ml-1 h-[20px]"
          on:click={useFullAmount}>
          {$_('bridgeForm.maxLabel')}
        </button>
      </div>
    {/if}
  </label>

  <label
    class="input-group relative rounded-lg bg-dark-2 justify-between items-center pr-4">
    <input
      type="number"
      placeholder="0.01"
      min="0"
      on:input={updateAmount}
      class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2"
      name="amount"
      bind:this={amountInput} />
    <SelectToken />
  </label>
</div>

{#if showFaucet}
  <div class="flex" style="flex-direction:row-reverse">
    <div class="flex items-start">
      <button class="btn" on:click={() => (isFaucetModalOpen = true)}>
        <Funnel class="mr-2" /> Faucet
      </button>
    </div>
  </div>

  <FaucetModal
    onMint={async () => await getUserBalance($signer, $token, $fromChain)}
    bind:isOpen={isFaucetModalOpen} />
{/if}

<To bind:showTo bind:to />

<ProcessingFee bind:customFee bind:recommendedFee />

<Memo bind:memo bind:memoError />

{#if loading}
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
      controlsLayout={[]} />
  </button>
{:else if !requiresAllowance}
  <button
    class="btn btn-accent w-full mt-4"
    on:click={bridge}
    disabled={btnDisabled}>
    {$_('home.bridge')}
  </button>
{:else}
  <button
    class="btn btn-accent approve-btn w-full mt-4"
    on:click={approve}
    disabled={btnDisabled}>
    {$_('home.approve')}
  </button>
{/if}

<style>
  /* hide number input arrows */
  input[type='number']::-webkit-outer-spin-button,
  input[type='number']::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
    -moz-appearance: textfield !important;
  }

  .btn.btn-accent.approve-btn {
    background-color: #4c1d95;
    border-color: #4c1d95;
    color: #ffffff;
  }

  .btn.btn-accent.approve-btn:hover {
    background-color: #5b21b6;
    border-color: #5b21b6;
  }
</style>
