<script>
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <div class="form-control">
    <TokenDropdown {tokens} onSelectedTokenChange={() => {}} />
  </div></Card>
