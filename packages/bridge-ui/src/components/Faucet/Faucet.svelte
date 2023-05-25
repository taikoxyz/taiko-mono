<script lang="ts">
  import { ethers, type Signer } from 'ethers';

  import { L1_CHAIN_NAME, L2_CHAIN_NAME } from '../../constants/envVars';
  import type { Chain } from '../../domain/chain';
  import type { Token } from '../../domain/token';
  import { fromChain } from '../../store/chain';
  import { signer } from '../../store/signer';
  import { token } from '../../store/token';
  import { pendingTransactions } from '../../store/transaction';
  import { isTestToken } from '../../token/tokens';
  import { getIsMintedWithEstimation } from '../../utils/getIsMintedWithEstimation';
  import { getLogger } from '../../utils/logger';
  import { mintERC20 } from '../../utils/mintERC20';
  import Button from '../Button.svelte';
  import Loading from '../Loading.svelte';
  import {
    errorToast,
    successToast,
    warningToast,
  } from '../NotificationToast.svelte';
  import TestTokenDropdown from './TestTokenDropdown.svelte';

  const log = getLogger('component:Faucet');

  let actionDisabled: boolean = true;
  let loading: boolean = false;
  let errorReason: string = '';

  async function shouldDisableButton(signer: Signer, _token: Token) {
    if (!signer || !_token || !isTestToken(_token)) {
      // If signer or token is missing, the button
      // should remained disabled
      return true;
    }

    loading = true;

    try {
      const [userHasAlreadyClaimed, estimatedGas] =
        await getIsMintedWithEstimation(signer, _token);

      if (userHasAlreadyClaimed) {
        errorReason = 'Token already minted';
        return true;
      }

      const balance = await signer.getBalance();

      if (balance.gt(estimatedGas)) {
        log(`Token ${_token.symbol} can be minted`);

        errorReason = '';
        return false;
      }

      errorReason = 'Insufficient balance';
    } catch (error) {
      console.error(error);

      errorToast(
        `There seems to be a problem with minting ${_token.symbol} tokens.`,
      );

      errorReason = 'Cannot mint token';
    } finally {
      loading = false;
    }

    return true;
  }

  async function mint(fromChain: Chain, signer: Signer, _token: Token) {
    loading = true;

    try {
      const tx = await mintERC20(fromChain.id, _token, signer);

      successToast(`Transaction sent to mint ${_token.symbol} tokens.`);

      await pendingTransactions.add(tx, signer);

      successToast(
        `<strong>Transaction completed!</strong><br />Your ${_token.symbol} tokens are in your wallet.`,
      );

      // Re-assignment is needed to trigger checks on the current token
      $token = _token;
    } catch (error) {
      console.error(error);

      const headerError = '<strong>Failed to mint tokens</strong>';
      if (error.cause?.status === 0) {
        const explorerUrl = `${fromChain.explorerUrl}/tx/${error.cause.transactionHash}`;
        const htmlLink = `<a href="${explorerUrl}" target="_blank"><b><u>here</u></b></a>`;
        errorToast(
          `${headerError}<br />Click ${htmlLink} to see more details on the explorer.`,
          true, // dismissible
        );
      } else if (error.cause?.code === ethers.errors.ACTION_REJECTED) {
        warningToast(`Transaction has been rejected.`);
      } else {
        errorToast(`${headerError}<br />Try again later.`);
      }
    } finally {
      loading = false;
    }
  }

  $: shouldDisableButton($signer, $token)
    .then((disable) => (actionDisabled = disable))
    .catch((error) => console.error(error));
</script>

<div class="space-y-4">
  <TestTokenDropdown bind:selectedToken={$token} />

  {#if $token && isTestToken($token)}
    <p>
      You can request 50 {$token.symbol}. {$token.symbol} is only available to be
      minted on {L1_CHAIN_NAME}. If you are on {L2_CHAIN_NAME}, your network
      will be changed first. You must have a small amount of ETH in your {L1_CHAIN_NAME}
      wallet to send the transaction.
    </p>
  {:else}
    <p>No token selected to mint.</p>
  {/if}

  <Button
    type="accent"
    class="w-full"
    disabled={actionDisabled || loading}
    on:click={() => mint($fromChain, $signer, $token)}>
    <span>
      {#if loading}
        <Loading />
      {:else if actionDisabled}
        {errorReason || 'Mint'}
      {:else}
        Mint {$token.name}
      {/if}
    </span>
  </Button>
</div>
