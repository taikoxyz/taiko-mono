<script lang="ts">
  import { type Connector, connect } from '@wagmi/core'
  import loglevel from 'loglevel'
  import { client } from '../../../libs/wagmi'
  import { Modal } from '../Modal'

  const log = loglevel.getLogger('WalletListModal')

  let open = false
  let connecting = false

  export function show() {
    open = true
  }

  export function hide() {
    open = false
  }

  async function connectWallet(connector: Connector) {
    if (client.connector?.id !== connector.id) {
      connecting = true

      try {
        const result = await connect({ connector })
      } catch (e) {
        console.log('Error', e)
      } finally {
        connecting = false
      }
    }
  }
</script>

<Modal closeable="outside" bind:open>
  <ul class="menu space-y-4">
    {#each client.connectors as connector}
      <li>
        <button class="btn" on:click={() => connectWallet(connector)}>
          {connector.name}
        </button>
      </li>
    {/each}
  </ul>
</Modal>
