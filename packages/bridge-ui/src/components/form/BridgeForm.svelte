<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { selectedToken } from '../../store/token';
  import { fromChain, toChain } from '../../store/chain';
  import { activeBridge, bridgeType } from '../../store/bridge';
  import { signer } from '../../store/signer';
  import { BigNumber, Contract, ethers, Signer } from 'ethers';
  import ProcessingFee from './ProcessingFee';
  import SelectToken from '../buttons/SelectToken.svelte';

  import type { Token } from '../../domain/token';
  import type { BridgeOpts, BridgeType } from '../../domain/bridge';

  import type { Chain } from '../../domain/chain';
  import { truncateString } from '../../utils/truncateString';
  import {
    pendingTransactions,
    transactions as transactionsStore,
  } from '../../store/transaction';
  import Memo from './Memo.svelte';
  import ERC20_ABI from '../../constants/abi/ERC20';
  import TokenVaultABI from '../../constants/abi/TokenVault';
  import type { BridgeTransaction } from '../../domain/transaction';
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
  import { ProcessingFeeMethod } from '../../domain/fee';
  import Button from '../buttons/Button.svelte';
  import { storageService } from '../../storage/services';
  import Loading from '../Loading.svelte';

  let amount: string;
  let amountInput: HTMLInputElement;
  let requiresAllowance: boolean = false;
  let btnDisabled: boolean = true;
  let tokenBalance: string;
  let memo: string = '';
  let loading: boolean = false;
  let isFaucetModalOpen: boolean = false;
  let memoError: string;
  let to: string = '';
  let showTo: boolean = false;
  let feeMethod: ProcessingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  let feeAmount: string = '0';

  // TODO: too much going on here. We need to extract
  //       logic and unit test the hell out of all this.

  async function addrForToken() {
    let addr = $selectedToken.addresses.find(
      (chainAddress) => chainAddress.chainId === $fromChain.id,
    ).address;

    if (
      $selectedToken.symbol !== ETHToken.symbol &&
      (!addr || addr === '0x00')
    ) {
      const srcChainAddr = $selectedToken.addresses.find(
        (chainAddress) => chainAddress.chainId === $toChain.id,
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

  async function getUserBalance(signer: ethers.Signer, token: Token) {
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
    const allowance = await $activeBridge.requiresAllowance({
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

      const tx = await $activeBridge.approve({
        amountInWei: ethers.utils.parseUnits(amount, $selectedToken.decimals),
        signer: $signer,
        contractAddress: await addrForToken(),
        spenderAddress: tokenVaults[$fromChain.id],
      });

      pendingTransactions.add(tx, $signer, () =>
        successToast('Transaction completed!'),
      );

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
      const gasEstimate = await $activeBridge.estimateGas({
        ...bridgeOpts,
        amountInWei: BigNumber.from(1),
      });
      const feeData = await fetchFeeData();
      const requiredGas = gasEstimate.mul(feeData.gasPrice);
      const userBalance = await $signer.getBalance('latest');

      let balanceAvailableForTx = userBalance;

      if ($selectedToken.symbol === ETHToken.symbol) {
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

      const amountInWei = ethers.utils.parseUnits(
        amount,
        $selectedToken.decimals,
      );

      const provider = providers[$toChain.id];
      const destTokenVaultAddress = tokenVaults[$toChain.id];
      let isBridgedTokenAlreadyDeployed =
        await checkIfTokenIsDeployedCrossChain(
          $selectedToken,
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

      const tx = await $activeBridge.bridge(bridgeOpts);

      // tx.chainId is not set immediately but we need it later. set it
      // manually.
      tx.chainId = $fromChain.id;
      const userAddress = await $signer.getAddress();
      let transactions: BridgeTransaction[] =
        await storageService.getAllByAddress(userAddress);

      let bridgeTransaction: BridgeTransaction = {
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        symbol: $selectedToken.symbol,
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

      storageService.updateStorageByAddress(userAddress, transactions);

      pendingTransactions.add(tx, $signer, () =>
        successToast('Transaction completed!'),
      );

      const allTransactions = $transactionsStore;

      // get full BridgeTransaction object
      bridgeTransaction = await storageService.getTransactionByHash(
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
    if ($selectedToken.symbol === ETHToken.symbol) {
      try {
        const feeData = await fetchFeeData();
        const gasEstimate = await $activeBridge.estimateGas({
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
    if (feeMethod === ProcessingFeeMethod.NONE) {
      return undefined;
    }

    return BigNumber.from(ethers.utils.parseEther(feeAmount));
  }

  $: getUserBalance($signer, $selectedToken);

  $: isBtnDisabled(
    $signer,
    amount,
    $selectedToken,
    tokenBalance,
    memoError,
    $fromChain,
  )
    .then((d) => (btnDisabled = d))
    .catch((e) => console.error(e));

  $: checkAllowance(amount, $selectedToken, $bridgeType, $fromChain, $signer)
    .then((a) => (requiresAllowance = a))
    .catch((e) => console.error(e));

  // TODO: we need to simplify this crazy condition
  $: showFaucet =
    $fromChain && // chain selected?
    $fromChain.id === L1_CHAIN_ID && // are we in L1?
    $selectedToken.symbol !== ETHToken.symbol && // bridging ERC20?
    $signer && // wallet connected?
    tokenBalance &&
    ethers.utils
      .parseUnits(tokenBalance, $selectedToken.decimals)
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
          {$selectedToken.symbol}
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
    onMint={async () => await getUserBalance($signer, $selectedToken)}
    bind:isOpen={isFaucetModalOpen} />
{/if}

<To bind:showTo bind:to />

<ProcessingFee bind:method={feeMethod} bind:amount={feeAmount} />

<Memo bind:memo bind:memoError />

{#if loading}
  <Button type="accent" size="lg" class="w-full" disabled={true}>
    <Loading />
  </Button>
{:else if !requiresAllowance}
  <Button
    type="accent"
    size="lg"
    class="w-full"
    on:click={bridge}
    disabled={btnDisabled}>
    {$_('home.bridge')}
  </Button>
{:else}
  <Button
    type="accent"
    class="w-full"
    on:click={approve}
    disabled={btnDisabled}>
    {$_('home.approve')}
  </Button>
{/if}

<style>
  /* hide number input arrows */
  input[type='number']::-webkit-outer-spin-button,
  input[type='number']::-webkit-inner-spin-button {
    -webkit-appearance: none;
    margin: 0;
    -moz-appearance: textfield !important;
  }
</style>
