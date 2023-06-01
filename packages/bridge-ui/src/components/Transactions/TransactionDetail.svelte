<script lang="ts">
  import { ethers } from 'ethers';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';

  import { chains } from '../../chain/chains';
  import type { BridgeTransaction } from '../../domain/transaction';
  import { addressSubsection } from '../../utils/addressSubsection';
  import Modal from '../Modal.svelte';

  // TODO: can we always guarantee that this object is defined?
  //       in which case we need to guard => transaction?.prop
  export let transaction: BridgeTransaction;
  export let onClose: () => void;
</script>

<Modal {onClose} isOpen={!!transaction} title="Transaction Details">
  <table
    class="table table-normal w-full md:w-2/3 m-auto table-fixed border-spacing-0 text-sm md:text-base">
    <tr>
      <td>Tx hash</td>
      <td class="text-right">
        <a
          class="link flex items-center justify-end"
          target="_blank"
          rel="noreferrer"
          href={`${chains[transaction.srcChainId].explorerUrl}/tx/${
            transaction.hash
          }`}>
          <span class="mr-1">{addressSubsection(transaction.hash)}</span>
          <ArrowTopRightOnSquare />
        </a>
      </td>
    </tr>
    {#if transaction.message}
      <tr>
        <td>Sender</td>
        <td class="text-right">
          {addressSubsection(transaction.message.sender)}
        </td>
      </tr>
      <tr>
        <td>Owner</td>
        <td class="text-right">
          {addressSubsection(transaction.message.owner)}
        </td>
      </tr>
      <tr>
        <td>Refund address</td>
        <td class="text-right">
          {addressSubsection(transaction.message.refundAddress)}
        </td>
      </tr>
      {#if transaction.message.callValue}
        <tr>
          <td>Call value</td>
          <td class="text-right">
            {ethers.utils.formatEther(transaction.message.callValue.toString())}
            ETH
          </td>
        </tr>
      {/if}
      {#if transaction.message.processingFee}
        <tr>
          <td>Processing fee</td>
          <td class="text-right">
            {ethers.utils.formatEther(transaction.message.processingFee)} ETH
          </td>
        </tr>
      {/if}
      <tr>
        <td>Gas limit</td>
        <td class="text-right">
          {transaction.message.gasLimit}
        </td>
      </tr>
      <tr>
        <td class="!align-top">Memo</td>
        <td class="text-right">
          <textarea
            readonly
            class="bg-dark-2 rounded-lg p-2 outline-none"
            value={transaction.message.memo.trim()} />
        </td>
      </tr>
    {/if}
  </table>
</Modal>
