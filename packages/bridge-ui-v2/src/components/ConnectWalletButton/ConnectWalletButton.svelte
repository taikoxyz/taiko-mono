<script lang="ts">
  import { Button } from 'flowbite-svelte'

  import { t } from '../../libs/i18n'
  import { open as openWalletListModal } from '../WalletListModal'

  function onClick() {
    openWalletListModal()
  }
</script>

<Button on:click={onClick}>
  {$t('wallet.button.connect')}
</Button>
