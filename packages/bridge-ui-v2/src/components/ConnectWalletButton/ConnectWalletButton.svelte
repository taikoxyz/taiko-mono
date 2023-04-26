<script lang="ts">
  import { Button } from 'flowbite-svelte'
  import { getContext } from 'svelte'
  import type { Writable } from 'svelte/store'

  import { t } from '../../libs/i18n'
  import { WalletListModal } from '../WalletListModal'

  const walletListModal = getContext<Writable<WalletListModal>>(WalletListModal.name)

  function onClick() {
    $walletListModal.show()
  }
</script>

<Button on:click={onClick}>
  {$t('wallet.button.connect')}
</Button>
