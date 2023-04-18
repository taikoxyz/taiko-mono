<script lang="ts">
  import { t } from '../../libs/i18n'
  import { Button } from '../Button'

  const onClick = () => {
    console.log('onClick')
  }
</script>

<Button type="primary" on:click={onClick}>{$t('connect_wallet')}</Button>
