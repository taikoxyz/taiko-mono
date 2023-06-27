<script>
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
  import AmountInput from '$components/AmountInput';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <TokenDropdown {tokens} onChange={(token) => {}} />
  <AmountInput />
</Card>
