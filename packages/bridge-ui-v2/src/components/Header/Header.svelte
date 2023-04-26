<script lang="ts">
  import { DarkMode } from 'flowbite-svelte'

  import { t } from '../../libs/i18n'
  import { account } from '../../stores/account'
  import { ConnectWalletButton } from '../ConnectWalletButton'

  $: isConnected = $account && $account.isConnected
  $: isConnecting = $account && $account.isConnecting
  $: isDisconnected = $account ? $account.isDisconnected : true
  $: status = $account ? $account.status : 'disconnected'
</script>

<header class="flex justify-between">
  <h1>TAIKO</h1>
  <h3>{$t(`wallet.status.${status}`)}</h3>
  <div />
  <div>
    {#if isDisconnected}
      <ConnectWalletButton />
    {/if}
  </div>
  <DarkMode />
</header>
