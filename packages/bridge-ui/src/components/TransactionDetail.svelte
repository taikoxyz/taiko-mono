<script lang="ts">
  import { ethers } from 'ethers';
  import { ArrowTopRightOnSquare } from 'svelte-heros-v2';
  import Modal from './modals/Modal.svelte';
  import type { BridgeTransaction } from '../domain/transaction';
  import { addressSubsection } from '../utils/addressSubsection';
  import { chains } from '../chain/chains';

  // TODO: can we always guarantee that this object is defined?
  //       in which case we need to guard => transaction?.prop
  export let transaction: BridgeTransaction;
  export let onClose: () => void;
</script>

<Modal {onClose} isOpen={!!transaction} title="Transaction Details">
  <table
    class="table table-normal w-full md:w-2/3 m-auto table-fixed border-spacing-0 text-sm md:text-base">
    <tr>
      <td>Tx Hash</td>
      <td class="text-right">
        <a
          class="link flex items-center justify-end"
          target="_blank"
          rel="noreferrer"
          href={`${chains[transaction.fromChainId].explorerUrl}/tx/${
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
        <td>Refund Address</td>
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
          <td>Processing Fee</td>
          <td class="text-right">
            {ethers.utils.formatEther(transaction.message.processingFee)} ETH
          </td>
        </tr>
      {/if}
      <tr>
        <td>Gas Limit</td>
        <td class="text-right">
          {transaction.message.gasLimit}
        </td>
      </tr>
      <tr>
        <td>Memo</td>
        <td class="text-right">
          <div class="overflow-auto">
            {transaction.message.memo}
          </div>
        </td>
      </tr>
    {/if}
  </table>
</Modal>
