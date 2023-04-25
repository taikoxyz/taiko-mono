<script lang="ts">
  import { type Connector, connect } from '@wagmi/core'
  import { client } from '../../../libs/wagmi'
  import { Modal } from '../Modal'

  let open = false

  export function show() {
    open = true
  }

  export function hide() {
    open = false
  }

  function connectWallet(connector: Connector) {
    if (client.connector?.id !== connector.id) {
      connect({ connector })
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
