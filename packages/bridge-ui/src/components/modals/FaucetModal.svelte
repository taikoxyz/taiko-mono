<script lang="ts">
  import { BigNumber, ethers, Signer } from 'ethers';
  import { pendingTransactions } from '../../store/transactions';
  import { signer } from '../../store/signer';
  import { errorToast, successToast } from '../../utils/toast';
  import { _ } from 'svelte-i18n';
  import MintableERC20 from '../../constants/abi/MintableERC20';
  import { fromChain } from '../../store/chain';
  import { fetchSigner, switchNetwork } from '@wagmi/core';
  import { CHAIN_MAINNET } from '../../domain/chain';
  import Modal from './Modal.svelte';
  import { onMount } from 'svelte';
  import { token } from '../../store/token';

  export let isOpen: boolean = false;
  export let onMint: () => Promise<void>;

  let disabled: boolean = true;

  async function isBtnDisabled(signer: Signer) {
    if (!signer) return;

    const balance = await signer.getBalance();
    const address = await signer.getAddress();

    const contract = new ethers.Contract($token.addresses[0].address, MintableERC20, signer);

    const gas = await contract.estimateGas.mint(address);
    const gasPrice = await signer.getGasPrice();
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
          chainId: CHAIN_MAINNET.id,
        });
        const wagmiSigner = await fetchSigner();

        signer.set(wagmiSigner);
      }
      const contract = new ethers.Contract($token.addresses[0].address, MintableERC20, $signer);

      const address = await $signer.getAddress();
      const tx = await contract.mint(address);

      pendingTransactions.update((store) => {
        store.push(tx);
        return store;
      });

      successToast($_('toast.transactionSent'));
      isOpen = false;
      await $signer.provider.waitForTransaction(tx.hash, 1);

      await onMint();
    } catch (e) {
      console.log(e);
      errorToast($_('toast.errorSendingTransaction'));
    }
  }

  $: isBtnDisabled($signer).catch((e) => console.error(e));
  $: mainnetName = import.meta.env ? import.meta.env.VITE_MAINNET_CHAIN_NAME : 'Ethereum A2';
  $: taikonetName = import.meta.env ? import.meta.env.VITE_TAIKO_CHAIN_NAME : 'Taiko A2';

  onMount(async () => {
    isBtnDisabled($signer);
  });
</script>

<Modal title={'ERC20 Faucet'} bind:isOpen>
  You can request 50 {$token.symbol}. {$token.symbol} is only available to be minted on {mainnetName}.
  If you are on {taikonetName}, your network will be changed first. You must have a small amount of
  ETH in your {mainnetName} wallet to send the transaction.
  <br />
  <button
    class="btn btn-dark-5 h-[60px] text-base"
    {disabled}
    on:click={async () => {
      await mint();
    }}
  >
    {#if disabled}
      Insufficient ETH
    {:else}
      Mint
    {/if}
  </button>
</Modal>
