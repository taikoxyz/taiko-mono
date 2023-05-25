<script lang="ts">
  import { ethers,Signer } from 'ethers';
  
  import { L1_CHAIN_NAME, L2_CHAIN_NAME } from '../constants/envVars';
  import type { Token } from '../domain/token';
  import { fromChain } from '../store/chain';
  import { signer } from '../store/signer';
  import { token } from '../store/token';
  import { pendingTransactions } from '../store/transaction';
  import { getIsMintedWithEstimation } from '../utils/getIsMintedWithEstimation';
  import { mintERC20 } from '../utils/mintERC20';
  import Modal from './Modal.svelte';
  import {
    errorToast,
    successToast,
    warningToast,
  } from './NotificationToast.svelte';

  export let isOpen: boolean = false;
  export let onMint: () => Promise<void>;

  let disabled: boolean = true;
  let errorReason: string;

  async function shouldEnableButton(_signer: Signer, _token: Token) {
    if (!_signer || !_token) {
      // If signer or token is missing, the button
      // should remained disabled
      disabled = true;
      return;
    }

    try {
      const [userHasAlreadyClaimed, estimatedGas] =
        await getIsMintedWithEstimation(_signer, _token);

      if (userHasAlreadyClaimed) {
        disabled = true;
        errorReason = 'You have already claimed';
        return;
      }

      const balance = await _signer.getBalance();

      if (balance.lt(estimatedGas)) {
        disabled = true;
      } else {
        disabled = false;
      }
    } catch (error) {
      console.error(error);
      errorToast(
        `There seems to be a problem with minting ${_token.symbol} tokens.`,
      );
    }
  }

  async function mint() {
    try {
      const tx = await mintERC20($fromChain.id, $token, $signer);

      successToast(`Transaction sent to mint ${$token.symbol} tokens.`);

      pendingTransactions.add(tx, $signer).then(() => {
        successToast(
          `<strong>Transaction completed!</strong><br />Your ${$token.symbol} tokens are in your wallet.`,
        );
        onMint();
      });

      isOpen = false;
    } catch (error) {
      console.error(error);

      const headerError = '<strong>Failed to mint tokens</strong>';
      if (error.cause?.status === 0) {
        const explorerUrl = `${$fromChain.explorerUrl}/tx/${error.cause.transactionHash}`;
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

  $: shouldEnableButton($signer, $token);
</script>

<Modal title={'ERC20 Faucet'} bind:isOpen>
  You can request 50 {$token.symbol}. {$token.symbol} is only available to be minted
  on {L1_CHAIN_NAME}. If you are on {L2_CHAIN_NAME}, your network will be
  changed first. You must have a small amount of ETH in your {L1_CHAIN_NAME} wallet
  to send the transaction.
  <br />
  <button class="btn btn-dark-5 h-[60px] text-base" {disabled} on:click={mint}>
    {#if disabled}
      {errorReason ?? 'Insufficient ETH'}
    {:else}
      Mint
    {/if}
  </button>
</Modal>
