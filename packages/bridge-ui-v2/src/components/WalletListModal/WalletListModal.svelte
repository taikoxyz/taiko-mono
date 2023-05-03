<script lang="ts">
  import { connect, type Connector } from '@wagmi/core'
  import { Modal } from 'flowbite-svelte'

  import { getLogger } from '../../libs/logger'
  import { walletIdToIconComponent } from '../../libs/util/walletIdToIconComponent'
  import { client } from '../../libs/wagmi'
  import { openModal } from './api'

  const log = getLogger('WalletListModal')

  let connecting = false

  async function connectWallet(connector: Connector) {
    if (client.connector?.id !== connector.id) {
      connecting = true

      try {
        const result = await connect({ connector })
        log('Wallet connected', result)
      } catch (error) {
        log('Error connecting wallet', error)
      } finally {
        connecting = false
      }
    }
  }
</script>

<Modal title="Connect wallet" bind:open={$openModal} size="xs" padding="xs">
  <p class="text-sm font-normal text-gray-500 dark:text-gray-400">
    Connect with one of our available wallet providers.
  </p>
  <ul class="my-4 space-y-3">
    {#each client.connectors as connector}
      <li>
        <button
          on:click={() => connectWallet(connector)}
          class="flex items-center w-full p-3 text-base font-bold text-gray-900 bg-gray-50 rounded-lg hover:bg-gray-100 group hover:shadow dark:bg-gray-600 dark:hover:bg-gray-500 dark:text-white">
          <svelte:component this={walletIdToIconComponent[connector.id]} />
          <span class="ml-3 whitespace-nowrap">{connector.name}</span>
        </button>
      </li>
    {/each}
  </ul>
</Modal>
