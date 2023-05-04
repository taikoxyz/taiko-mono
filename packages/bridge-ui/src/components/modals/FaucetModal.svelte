<script lang="ts">
  import { BigNumber, ethers } from 'ethers';
  import { pendingTransactions } from '../../store/transactions';
  import { signer } from '../../store/signer';
  import { _ } from 'svelte-i18n';
  import FreeMintERC20_ABI from '../../constants/abi/FreeMintERC20';
  import { fromChain } from '../../store/chain';
  import { fetchSigner, switchNetwork } from '@wagmi/core';
  import Modal from './Modal.svelte';
  import { onMount } from 'svelte';
  import { token } from '../../store/token';
  import {
    L1_CHAIN_ID,
    L1_CHAIN_NAME,
    L2_CHAIN_NAME,
  } from '../../constants/envVars';
  import { errorToast, successToast } from '../Toast.svelte';

  export let isOpen: boolean = false;
  export let onMint: () => Promise<void>;

  let disabled: boolean = true;
  let errorReason: string;

  async function shouldEnableButton() {
    if (!$signer || !$token) {
      // If signer or token is missing, the button
      // should remained disabled
      disabled = true;
      return;
    }

    const balance = await $signer.getBalance();
    const address = await $signer.getAddress();

    const contract = new ethers.Contract(
      $token.addresses[0].address,
      FreeMintERC20_ABI,
      $signer,
    );

    const userHasAlreadyClaimed = await contract.minters(address);

    if (userHasAlreadyClaimed) {
      disabled = true;
      errorReason = 'You have already claimed';
      return;
    }

    const gas = await contract.estimateGas.mint(address);
    const gasPrice = await $signer.getGasPrice();
    const estimatedGas = BigNumber.from(gas).mul(gasPrice);

    if (balance.lt(estimatedGas)) {
      disabled = true;
    } else {
      disabled = false;
    }
  }

  async function mint() {
    try {
      if ($fromChain.id !== $token.addresses[0].chainId) {
        await switchNetwork({
          chainId: L1_CHAIN_ID,
        });
        const wagmiSigner = await fetchSigner();

        signer.set(wagmiSigner);
      }
      const contract = new ethers.Contract(
        $token.addresses[0].address,
        FreeMintERC20_ABI,
        $signer,
      );

      const address = await $signer.getAddress();
      const tx = await contract.mint(address);

      successToast($_('toast.transactionSent'));

      await pendingTransactions.add(tx, $signer);

      isOpen = false;

      successToast('Transaction completed!');

      await onMint();
    } catch (e) {
      // TODO: handle potential transaction failure
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    }
  }

  $: shouldEnableButton().catch((e) => console.error(e));

  onMount(() => {
    shouldEnableButton();
  });
</script>

<Modal title={'ERC20 Faucet'} bind:isOpen>
  You can request 50 {$token.symbol}. {$token.symbol} is only available to be minted
  on {L1_CHAIN_NAME}. If you are on {L2_CHAIN_NAME}, your network will be
  changed first. You must have a small amount of ETH in your {L1_CHAIN_NAME} wallet
  to send the transaction.
  <br />
  <button
    class="btn btn-dark-5 h-[60px] text-base"
    {disabled}
    on:click={async () => {
      await mint();
    }}>
    {#if disabled}
      {errorReason ?? 'Insufficient ETH'}
    {:else}
      Mint
    {/if}
  </button>
</Modal>
