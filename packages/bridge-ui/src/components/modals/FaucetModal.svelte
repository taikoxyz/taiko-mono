<script lang="ts">
  import { BigNumber, Signer, Contract } from 'ethers';
  import { pendingTransactions } from '../../store/transactions';
  import { signer } from '../../store/signer';
  import { _ } from 'svelte-i18n';
  import { FREE_MINT_ERC20_ABI } from '../../constants/abi';
  import { fromChain } from '../../store/chain';
  import Modal from './Modal.svelte';
  import { token } from '../../store/token';
  import {
    L1_CHAIN_ID,
    L1_CHAIN_NAME,
    L2_CHAIN_NAME,
  } from '../../constants/envVars';
  import { errorToast, successToast } from '../Toast.svelte';
  import { getLogger } from '../../utils/logger';
  import type { Token } from '../../domain/token';
  import { mintERC20 } from '../../utils/mintERC20';

  const log = getLogger('FaucetModal');

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
      const balance = await _signer.getBalance();
      const address = await _signer.getAddress();

      const l1TokenContract = new Contract(
        _token.addresses[0].address, // L1 address
        FREE_MINT_ERC20_ABI,
        _signer,
      );

      log(`Calling l1TokenContract.minters(${address})`);

      const userHasAlreadyClaimed = await l1TokenContract.minters(address);

      log(`userHasAlreadyClaimed ${_token.symbol}?`, userHasAlreadyClaimed);

      if (userHasAlreadyClaimed) {
        disabled = true;
        errorReason = 'You have already claimed';
        return;
      }

      const gas = await l1TokenContract.estimateGas.mint(address);
      const gasPrice = await $signer.getGasPrice();
      const estimatedGas = BigNumber.from(gas).mul(gasPrice);

      if (balance.lt(estimatedGas)) {
        disabled = true;
      } else {
        disabled = false;
      }
    } catch (e) {
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
    }
  }

  async function mint() {
    try {
      const tx = await mintERC20($fromChain.id, $token, $signer);

      successToast($_('toast.transactionSent'));

      pendingTransactions.add(tx, $signer).then(() => {
        successToast('Transaction completed!');
        onMint();
      });

      isOpen = false;
    } catch (e) {
      // TODO: handle potential transaction failure
      console.error(e);
      errorToast($_('toast.errorSendingTransaction'));
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
