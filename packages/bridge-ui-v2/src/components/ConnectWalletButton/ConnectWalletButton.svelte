<script lang="ts">
  import { getContext } from 'svelte'
  import { t } from '../../libs/i18n'
  import { Button } from '../Button'
  import { WalletListModal } from '../WalletListModal'
  import type { Writable } from 'svelte/store'

  const walletListModal = getContext<Writable<WalletListModal>>(WalletListModal.name)

  function onClick() {
    $walletListModal.show()
  }
</script>

<Button type="primary" on:click={onClick}>
  {$t('connect_wallet')}
</Button>
