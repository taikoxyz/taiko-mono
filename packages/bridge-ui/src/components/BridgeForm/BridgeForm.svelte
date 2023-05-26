<script lang="ts">
  import { fetchFeeData } from '@wagmi/core';
  import { BigNumber, Contract, ethers, type Signer } from 'ethers';
  import { _ } from 'svelte-i18n';

  import { chains } from '../../chain/chains';
  import { erc20ABI } from '../../constants/abi';
  import type { BridgeOpts, BridgeType } from '../../domain/bridge';
  import type { Chain } from '../../domain/chain';
  import { ProcessingFeeMethod } from '../../domain/fee';
  import { MessageStatus } from '../../domain/message';
  import type { Token } from '../../domain/token';
  import type { BridgeTransaction } from '../../domain/transaction';
  import { providers } from '../../provider/providers';
  import { storageService } from '../../storage/services';
  import { activeBridge, bridgeType } from '../../store/bridge';
  import { fromChain, toChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { token } from '../../store/token';
  import {
    pendingTransactions,
    transactions as transactionsStore,
  } from '../../store/transaction';
  import { isETH } from '../../token/tokens';
  import { checkIfTokenIsDeployedCrossChain } from '../../utils/checkIfTokenIsDeployedCrossChain';
  import { getAddressForToken } from '../../utils/getAddressForToken';
  import { isOnCorrectChain } from '../../utils/isOnCorrectChain';
  import { getLogger } from '../../utils/logger';
  import { truncateString } from '../../utils/truncateString';
  import { tokenVaults } from '../../vault/tokenVaults';
  import {
    errorToast,
    successToast,
    warningToast,
  } from '../NotificationToast.svelte';
  import ActionButtons from './ActionButtons.svelte';
  import Memo from './Memo.svelte';
  import ProcessingFee from './ProcessingFee.svelte';
  import SelectToken from './SelectToken.svelte';
  import To from './To.svelte';

  const log = getLogger('component:BridgeForm');

  let amount: string;

  let computingAllowance: boolean = false;
  let requiresAllowance: boolean = false;

  let actionDisabled: boolean = true;

  let computingTokenBalance: boolean = false;
  let tokenBalance: string;

  let memo: string = '';
  let showMemo: boolean = false;
  let memoError: string = '';

  let to: string = '';
  let showTo: boolean = false;

  let feeMethod: ProcessingFeeMethod = ProcessingFeeMethod.RECOMMENDED;
  let feeAmount: string = '0';

  // TODO: too much going on here. We need to extract
  //       logic and unit test the hell out of all this.

  async function updateTokenBalance(signer: Signer, token: Token) {
    if (signer && token) {
      computingTokenBalance = true;

      if (isETH(token)) {
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
          tokenBalance = '0.0';
          return;
        }

        if (address == ethers.constants.AddressZero) {
          tokenBalance = '0.0';
          return;
        }

        try {
          const tokenContract = new Contract(address, erc20ABI, signer);

          const balance = await tokenContract.balanceOf(
            await signer.getAddress(),
          );

          tokenBalance = ethers.utils.formatUnits(balance, token.decimals);

          log(`${token.symbol} balance is ${tokenBalance}`);
        } catch (error) {
          console.error(error);

          tokenBalance = '0.0';

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

    computingAllowance = true;

    const address = await getAddressForToken(
      token,
      fromChain,
      $toChain,
      signer,
    );

    log(`Checking allowance for token ${token.symbol}`);

    const isRequired = await $activeBridge.requiresAllowance({
      amountInWei: ethers.utils.parseUnits(amount, token.decimals),
      signer: signer,
      contractAddress: address,
      spenderAddress: tokenVaults[fromChain.id],
    });

    log(`Token ${token.symbol} requires allowance? ${isRequired}`);

    return isRequired;
  }

  async function checkActionDisabled(
    signer: Signer,
    amount: string,
    token: Token,
    tokenBalance: string,
    memoError: string,
    fromChain: Chain,
  ) {
    if (
      !signer ||
      !amount ||
      !tokenBalance ||
      !fromChain ||
      !chains[fromChain.id] ||
      memoError
    )
      return true;

    const isCorrectChain = await isOnCorrectChain(signer, fromChain.id);
    if (!isCorrectChain) return true;

    if (
      isNaN(parseFloat(amount)) ||
      ethers.utils.parseUnits(amount).eq(BigNumber.from(0))
    )
      return true;

    const parsedBalance = ethers.utils.parseUnits(tokenBalance, token.decimals);
    const parsedAmount = ethers.utils.parseUnits(amount, token.decimals);
    if (BigNumber.from(parsedBalance).lt(parsedAmount)) return true;

    return false;
  }

  // TODO: rethink this function. By passing the token value, we make sure that async
  //       changes in the token don't affect the execution of this function. However,
  //       there are other moving pieces here, although neither chain nor signer can change.
  //       Ideally we would pass all the values as arguments and break down this function.
  //       As for changing the state of `requiresAllowance`, we could do this in a wrapper.
  async function approve(_token: Token) {
    try {
      if (!requiresAllowance)
        throw Error('does not require additional allowance');

      const contractAddress = await getAddressForToken(
        _token,
        $fromChain,
        $toChain,
        $signer,
      );

      const spenderAddress = tokenVaults[$fromChain.id];

      log(`Approving token ${_token.symbol}`);

      const tx = await $activeBridge.approve({
        amountInWei: ethers.utils.parseUnits(amount, _token.decimals),
        signer: $signer,
        contractAddress,
        spenderAddress,
      });

      successToast('Transaction sent to approve tokens transfer.');

      await pendingTransactions.add(tx, $signer);

      requiresAllowance = false;

      successToast(
        `<strong>Tokens transfer approved!</strong><br />You can now proceed to bridge ${_token.symbol} tokens.`,
      );
    } catch (error) {
      console.error(error);

      const headerError = '<strong>Failed to approve</strong>';
      if (error.cause?.status === 0) {
        const explorerUrl = `${$fromChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (
        [error.code, error.cause?.code].includes(ethers.errors.ACTION_REJECTED)
      ) {
        warningToast(`Transaction has been rejected.`);
      } else {
        errorToast(`${headerError}<br />Try again later.`);
      }
    }
  }

  async function checkUserHasEnoughBalance(bridgeOpts: BridgeOpts) {
    const gasEstimate = await $activeBridge.estimateGas({
      ...bridgeOpts,
      // We need an amount, and user might not have entered one at this point
      amountInWei: BigNumber.from(1),
    });

    const feeData = await fetchFeeData();

    log('Fetched network information', feeData);

    const requiredGas = gasEstimate.mul(feeData.gasPrice);
    const userBalance = await $signer.getBalance('latest');

    let balanceAvailableForTx = userBalance;

    if (isETH($token)) {
      balanceAvailableForTx = userBalance.sub(ethers.utils.parseEther(amount));
    }

    const hasEnoughBalance = balanceAvailableForTx.gte(requiredGas);

    log(
      `Is required gas ${requiredGas} less than available balance ${balanceAvailableForTx}? ${hasEnoughBalance}`,
    );

    return hasEnoughBalance;
  }

  // TODO: exactly the same as `approve` function. See comment there.
  async function bridge(_token: Token) {
    try {
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

      const amountInWei = ethers.utils.parseUnits(amount, _token.decimals);

      const provider = providers[$toChain.id];
      const destTokenVaultAddress = tokenVaults[$toChain.id];

      // TODO: remove this, and move this check to the ERC20 bridge directly
      let isBridgedTokenAlreadyDeployed =
        await checkIfTokenIsDeployedCrossChain(
          _token,
          provider,
          destTokenVaultAddress,
          $toChain,
          $fromChain,
        );

      const bridgeAddress = chains[$fromChain.id].bridgeAddress;
      const tokenVaultAddress = tokenVaults[$fromChain.id];

      const tokenAddress = await getAddressForToken(
        _token,
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

      const tx = await $activeBridge.bridge(bridgeOpts);

      successToast('Transaction sent to bridge your funds.');

      await pendingTransactions.add(tx, $signer);

      // tx.chainId is not set immediately but we need it later.
      // Set it manually.
      tx.chainId = $fromChain.id;

      const userAddress = await $signer.getAddress();

      let transactions: BridgeTransaction[] =
        await storageService.getAllByAddress(userAddress);

      log('Preparing transaction for storage…');

      let bridgeTransaction: BridgeTransaction = {
        fromChainId: $fromChain.id,
        toChainId: $toChain.id,
        symbol: _token.symbol,
        amountInWei,
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

      // Get full BridgeTransaction object
      bridgeTransaction = await storageService.getTransactionByHash(
        userAddress,
        tx.hash,
      );

      log('Transaction to be prepended in the store', bridgeTransaction);

      transactionsStore.set([bridgeTransaction, ...allTransactions]);

      log('All transactions in store', $transactionsStore);

      // Reset form
      to = '';
      memo = '';
      amount = '';
      showTo = false;
      showMemo = false;

      // Re-selecting the token triggers reactivity
      // for showStepper, updateTokenBalance and checkButtonIsDisabled
      $token = $token;

      successToast(
        `<strong>Transaction completed!</strong><br />Your funds are getting ready to be claimed on ${$toChain.name} chain.`,
      );
    } catch (error) {
      console.error(error);

      const headerError = '<strong>Failed to bridge funds</strong>';
      if (error.cause?.status === 0) {
        const explorerUrl = `${$fromChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (
        [error.code, error.cause?.code].includes(ethers.errors.ACTION_REJECTED)
      ) {
        warningToast(`Transaction has been rejected.`);
      } else {
        errorToast(`${headerError}<br />Try again later.`);
      }
    }
  }

  async function useFullAmount() {
    if (isETH($token)) {
      try {
        const feeData = await fetchFeeData();
        const gasEstimate = await $activeBridge.estimateGas({
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
      } catch (error) {
        console.error(error);

        // In case of error default to using the full amount of ETH available.
        // The user would still not be able to make the restriction and will have to manually set the amount.
        amount = tokenBalance.toString();
      }
    } else {
      amount = tokenBalance.toString();
    }
  }

  function getProcessingFee() {
    if (feeMethod === ProcessingFeeMethod.NONE) {
      return undefined;
    }

    return BigNumber.from(ethers.utils.parseEther(feeAmount));
  }

  function updateAmount(event: Event) {
    const target = event.target as HTMLInputElement;
    amount = target.value;
  }

  $: updateTokenBalance($signer, $token).finally(() => {
    computingTokenBalance = false;
  });

  $: checkActionDisabled(
    $signer,
    amount,
    $token,
    tokenBalance,
    memoError,
    $fromChain,
  )
    .then((disabled) => (actionDisabled = disabled))
    .catch((error) => console.error(error));

  $: checkAllowance(amount, $token, $bridgeType, $fromChain, $signer)
    .then((isRequired) => (requiresAllowance = isRequired))
    .catch((error) => {
      console.error(error);
      requiresAllowance = false;
    })
    .finally(() => {
      computingAllowance = false;
    });

  $: amountEntered = Boolean(amount);
</script>

<div class="space-y-6 md:space-y-4">
  <div class="form-control">
    <label class="label" for="amount">
      <span class="label-text">{$_('bridgeForm.fieldLabel')}</span>

      {#if $signer && tokenBalance}
        <div class="label-text ">
          <span>
            {$_('bridgeForm.balance')}:
            {tokenBalance.length > 10
              ? `${truncateString(tokenBalance, 6)}…`
              : tokenBalance}
            {$token.symbol}
          </span>

          <button
            class="btn btn-xs rounded-md text-xs ml-1 h-[20px]"
            on:click={useFullAmount}>
            {$_('bridgeForm.maxLabel')}
          </button>
        </div>
      {/if}
    </label>

    <div
      class="flex relative rounded-md bg-dark-2 justify-between items-center pr-4">
      <input
        id="amount"
        name="amount"
        type="number"
        placeholder="0.01"
        min="0"
        class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2"
        value={amount}
        on:input={updateAmount} />
      <SelectToken />
    </div>
  </div>

  <div>
    <To bind:to bind:show={showTo} />
  </div>

  <div>
    <ProcessingFee bind:method={feeMethod} bind:amount={feeAmount} />
  </div>

  <div>
    <Memo bind:memo bind:error={memoError} bind:show={showMemo} />
  </div>

  <ActionButtons
    token={$token}
    {requiresAllowance}
    {computingAllowance}
    {tokenBalance}
    {computingTokenBalance}
    {actionDisabled}
    {amountEntered}
    {approve}
    {bridge} />
</div>
