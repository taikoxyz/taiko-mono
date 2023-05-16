<script lang="ts">
  import { _ } from 'svelte-i18n';
  import { LottiePlayer } from '@lottiefiles/svelte-lottie-player';

  import { token } from '../../store/token';
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
  } from '../../store/transactions';
  import Memo from './Memo.svelte';
  import { erc20ABI, tokenVaultABI } from '../../constants/abi';
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
  import { ProcessingFeeMethod } from '../../domain/fee';
  import Button from '../buttons/Button.svelte';
  import { storageService } from '../../storage/services';
  import { getLogger } from '../../utils/logger';
  import { getAddressForToken } from '../../utils/getAddressForToken';

  const log = getLogger('component:BridgeForm');

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

  async function getUserBalance(signer: ethers.Signer, token: Token) {
    if (signer && token) {
      if (token.symbol == ETHToken.symbol) {
        const userBalance = await signer.getBalance('latest');
        tokenBalance = ethers.utils.formatEther(userBalance);

        log('ETH balance:', tokenBalance);
      } else {
        let address: string;

        try {
          address = await getAddressForToken(
            token,
            $fromChain,
            $toChain,
            signer,
          );
        } catch (error) {
          console.error(error);
          tokenBalance = '0';
          return;
        }

        if (address == ethers.constants.AddressZero) {
          tokenBalance = '0';
          return;
        }

        try {
          const tokenContract = new Contract(address, erc20ABI, signer);
          const userBalance = await tokenContract.balanceOf(
            await signer.getAddress(),
          );
          tokenBalance = ethers.utils.formatUnits(userBalance, token.decimals);

          log(`${token.symbol} balance`, tokenBalance);
        } catch (error) {
          console.error(error);
          tokenBalance = '0';
          throw Error(`Failed to get balance for ${token.symbol}`, {
            cause: error,
          });
        }
      }
    }
  }

  async function checkAllowance(
    amount: string,
    token: Token,
    bridgeType: BridgeType,
    fromChain: Chain,
    signer: Signer,
  ) {
    if (!fromChain || !amount || !token || !bridgeType || !signer) return false;

    const address = await getAddressForToken(
      token,
      fromChain,
      $toChain,
      signer,
    );

    log(`Checking allowance for token ${token.symbol}`);

    const allowance = await $activeBridge.RequiresAllowance({
      amountInWei: ethers.utils.parseUnits(amount, token.decimals),
      signer: signer,
      contractAddress: address,
      spenderAddress: tokenVaults[fromChain.id],
    });

    log(`Token ${token.symbol} requires allowance:`, allowance);

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

      const contractAddress = await getAddressForToken(
        $token,
        $fromChain,
        $toChain,
        $signer,
      );

      const spenderAddress = tokenVaults[$fromChain.id];

      log(`Approving token ${$token.symbol}`);

      const tx = await $activeBridge.Approve({
        amountInWei: ethers.utils.parseUnits(amount, $token.decimals),
        signer: $signer,
        contractAddress,
        spenderAddress,
      });

      successToast($_('toast.transactionSent'));

      await pendingTransactions.add(tx, $signer);

      requiresAllowance = false;

      successToast($_('toast.transactionCompleted'));
    } catch (e) {
      console.error(e);
      // TODO: if we have TransactionReceipt here means the tx failed
      //       We might want to give the user a link to etherscan
      //       to see the tx details
      errorToast($_('toast.errorSendingTransaction'));
    } finally {
      loading = false;
    }
  }

  async function checkUserHasEnoughBalance(
    bridgeOpts: BridgeOpts,
  ): Promise<boolean> {
    const gasEstimate = await $activeBridge.EstimateGas({
      ...bridgeOpts,
      // We need an amount, and user might not have entered one at this point
      amountInWei: BigNumber.from(1),
    });

    const feeData = await fetchFeeData();

    log('Fetched network information', feeData);

    const requiredGas = gasEstimate.mul(feeData.gasPrice);
    const userBalance = await $signer.getBalance('latest');

    let balanceAvailableForTx = userBalance;

    if ($token.symbol === ETHToken.symbol) {
      balanceAvailableForTx = userBalance.sub(ethers.utils.parseEther(amount));
    }

    const hasEnoughBalance = balanceAvailableForTx.gte(requiredGas);

    log(
      `Is required gas ${requiredGas} less than available balance ${balanceAvailableForTx}?`,
      hasEnoughBalance,
    );

    return hasEnoughBalance;
  }

  async function bridge() {
    try {
      loading = true;

      if (requiresAllowance) {
        throw Error('requires additional allowance');
      }

      if (showTo && !ethers.utils.isAddress(to)) {
        throw Error('invalid custom recipient address');
      }

      const onCorrectChain = await isOnCorrectChain($signer, $fromChain.id);

      if (!onCorrectChain) {
        errorToast($_('toast.errorWrongNetwork'));
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

      const tokenAddress = await getAddressForToken(
        $token,
        $fromChain,
        $toChain,
        $signer,
      );

      const bridgeOpts: BridgeOpts = {
        amountInWei,
        signer: $signer,
        tokenAddress,
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        tokenVaultAddress,
        bridgeAddress,
        processingFeeInWei: getProcessingFee(),
        memo: memo,
        isBridgedTokenAlreadyDeployed,
        to: showTo && to ? to : await $signer.getAddress(),
      };

      const doesUserHaveEnoughBalance = await checkUserHasEnoughBalance(
        bridgeOpts,
      );

      if (!doesUserHaveEnoughBalance) {
        // TODO: about custom errors and catch it in the catch block?
        errorToast($_('toast.errorInsufficientBalance'));
        return;
      }

      log('Getting ready to bridge with options', bridgeOpts);

      const tx = await $activeBridge.Bridge(bridgeOpts);

      successToast($_('toast.transactionSent'));

      await pendingTransactions.add(tx, $signer);

      // tx.chainId is not set immediately but we need it later. set it
      // manually.
      tx.chainId = $fromChain.id;

      const userAddress = await $signer.getAddress();

      log('Storing transaction in local storage...');

      let transactions: BridgeTransaction[] =
        await storageService.getAllByAddress(userAddress);

      log('Preparing transaction for storage...');

      let bridgeTransaction: BridgeTransaction = {
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        symbol: $token.symbol,
        amountInWei: amountInWei,
        from: tx.from,
        hash: tx.hash,
        status: MessageStatus.New,
      };

      log('Transaction ready to be included in storage', bridgeTransaction);

      if (!transactions) {
        transactions = [bridgeTransaction];
      } else {
        transactions.push(bridgeTransaction);
      }

      storageService.updateStorageByAddress(userAddress, transactions);

      const allTransactions = $transactionsStore;

      // get full BridgeTransaction object
      bridgeTransaction = await storageService.getTransactionByHash(
        userAddress,
        tx.hash,
      );

      log('Transaction to be prepended in the store', bridgeTransaction);

      transactionsStore.set([bridgeTransaction, ...allTransactions]);

      log('All transactions in store', $transactionsStore);

      memo = '';

      successToast($_('toast.transactionCompleted'));
    } catch (e) {
      console.error(e);
      // TODO: Same as in approve()
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
          tokenAddress: await getAddressForToken(
            $token,
            $fromChain,
            $toChain,
            $signer,
          ),
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

  $: getUserBalance($signer, $token);

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
    .then((allowance) => (requiresAllowance = allowance))
    .catch((error) => {
      console.error(error);
      errorToast($_('toast.errorCheckingAllowance'));
    });

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

<div class="form-control my-10 md:my-8">
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
  <div class="flex my-10 md:my-8" style="flex-direction:row-reverse">
    <div class="flex items-start">
      <button class="btn" on:click={() => (isFaucetModalOpen = true)}>
        <Funnel class="mr-2" /> Faucet
      </button>
    </div>
  </div>

  <FaucetModal
    onMint={() => getUserBalance($signer, $token)}
    bind:isOpen={isFaucetModalOpen} />
{/if}

<To bind:showTo bind:to />

<ProcessingFee bind:method={feeMethod} bind:amount={feeAmount} />

<Memo bind:memo bind:memoError />

{#if loading}
  <Button type="accent" size="lg" class="w-full" disabled={true}>
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
