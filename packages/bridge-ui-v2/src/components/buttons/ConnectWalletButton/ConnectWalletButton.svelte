<script lang="ts">
  import { getContext } from 'svelte'
  import type { Writable } from 'svelte/store'

  import { t } from '../../../libs/i18n'
  import { WalletListModal } from '../../modals/WalletListModal'
  import { Button } from '../Button'

  const walletListModal = getContext<Writable<WalletListModal>>(WalletListModal.name)

  function onClick() {
    $walletListModal.show()
  }
</script>

<Button type="primary" on:click={onClick}>
  {$t('wallet.button.connect')}
</Button>
