<script>
  import { Card } from '$components/Card';
  import { t } from '$libs/i18n';

  import ChainDropdown from './ChainDropdown.svelte';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <div class="form-control">
    <label for="from-chain" class="label">
      <span>From:</span>
      <ChainDropdown />
    </label>
  </div>
</Card>
