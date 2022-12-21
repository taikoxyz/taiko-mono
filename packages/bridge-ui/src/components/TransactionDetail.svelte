<script lang="ts">
  import { ethers } from "ethers";

  import { truncateString } from "../utils/truncateString";
  import TransactionsIcon from "./icons/Transactions.svelte";
  import Modal from "./modals/Modal.svelte";
  import { chains } from "../domain/chain";
  import { showTransactionDetails } from "../store/transactions";

  export let transaction;
</script>
<Modal onClose={() => $showTransactionDetails = undefined} isOpen={!!transaction} title="Transaction Detail">
      <table class="table table-normal w-2/3 m-auto">
        <tr>
          <td>Tx Hash</td>
          <td class="text-right">
            <a class="link flex items-center justify-end" target="_blank" rel="noreferrer" href={`${chains[transaction.fromChainId].explorerUrl}/tx/${transaction.ethersTx.hash}`}>
              {truncateString(transaction.ethersTx.hash)}
              <TransactionsIcon />
            </a>
          </td>
        </tr>
        {#if transaction.message}
        <tr>
          <td>Sender</td>
          <td class="text-right">
            {truncateString(transaction.message.sender)}
          </td>
        </tr>
        <tr>
          <td>Owner</td>
          <td class="text-right">
            {truncateString(transaction.message.owner)}
          </td>
        </tr>
        <tr>
          <td>Refund Address</td>
          <td class="text-right">
            {truncateString(transaction.message.refundAddress)}
          </td>
        </tr>
        {#if transaction.message.callValue}
        <tr>
          <td>Call value</td>
          <td class="text-right">
            {ethers.utils.formatEther(transaction.message.callValue)} ETH
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
          <td>Data</td>
          <td class="text-right">
            {transaction.message.data}
          </td>
        </tr>
        <tr>
          <td>Memo</td>
          <td class="text-right">
            {transaction.message.memo}
          </td>
        </tr>
        {/if}
      </table>
    </Modal>