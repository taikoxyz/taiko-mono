<script lang="ts">
  import { pendingTransactions } from '../../store/transaction';
  import type { Token } from '../../domain/token';
  import {
    errorToast,
    successToast,
    warningToast,
  } from '../NotificationToast.svelte';
  import TestTokenDropdown from './TestTokenDropdown.svelte';
  import { type Signer, ethers } from 'ethers';
  import { getIsMintedWithEstimation } from '../../utils/getIsMintedWithEstimation';
  import { mintERC20 } from '../../utils/mintERC20';
  import type { Chain } from '../../domain/chain';
  import { signer } from '../../store/signer';
  import { fromChain } from '../../store/chain';
  import { L1_CHAIN_NAME, L2_CHAIN_NAME } from '../../constants/envVars';
  import Button from '../Button.svelte';
  import { getLogger } from '../../utils/logger';
  import Loading from '../Loading.svelte';

  const log = getLogger('component:Faucet');

  let tokenToMint: Token;
  let mintButtonDisabled: boolean = true;
  let mintButtonLoading: boolean = false;
  let errorReason: string = '';

  async function shouldDisableButton(signer: Signer, token: Token) {
    if (!signer || !token) {
      // If signer or token is missing, the button
      // should remained disabled
      return true;
    }

    mintButtonLoading = true;

    try {
      const [userHasAlreadyClaimed, estimatedGas] =
        await getIsMintedWithEstimation(signer, token);

      if (userHasAlreadyClaimed) {
        errorReason = 'Token already minted';
        return true;
      }

      const balance = await signer.getBalance();

      if (balance.gt(estimatedGas)) {
        log(`Token ${token.symbol} can be minted`);

        errorReason = '';
        return false;
      }

      errorReason = 'Insufficient balance';
    } catch (error) {
      console.error(error);

      errorToast(
        `There seems to be a problem with minting ${token.symbol} tokens.`,
      );

      errorReason = 'Cannot mint token';
    } finally {
      mintButtonLoading = false;
    }

    return true;
  }

  async function mint(fromChain: Chain, signer: Signer, token: Token) {
    try {
      const tx = await mintERC20(fromChain.id, token, signer);

      successToast(`Transaction sent to mint ${token.symbol} tokens.`);

      pendingTransactions.add(tx, signer).then(() => {
        successToast(
          `<strong>Transaction completed!</strong><br />Your ${token.symbol} tokens are in your wallet.`,
        );
      });
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
    }
  }

  $: shouldDisableButton($signer, tokenToMint)
    .then((disable) => (mintButtonDisabled = disable))
    .catch((error) => console.error(error));
</script>

<div class="space-y-4">
  <TestTokenDropdown bind:selectedToken={tokenToMint} />

  {#if tokenToMint}
    <p>
      You can request 50 {tokenToMint.symbol}. {tokenToMint.symbol} is only available
      to be minted on {L1_CHAIN_NAME}. If you are on {L2_CHAIN_NAME}, your
      network will be changed first. You must have a small amount of ETH in your {L1_CHAIN_NAME}
      wallet to send the transaction.
    </p>
  {:else}
    <p>No token to mint.</p>
  {/if}

  <Button
    type="accent"
    class="w-full"
    disabled={mintButtonDisabled}
    on:click={() => mint($fromChain, $signer, tokenToMint)}>
    <span>
      {#if mintButtonLoading}
        <Loading />
      {:else if mintButtonDisabled}
        {errorReason || 'Mint'}
      {:else}
        Mint {tokenToMint.name}
      {/if}
    </span>
  </Button>
</div>
