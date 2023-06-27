<script>
  import { t } from 'svelte-i18n';

  import AmountInput from '$components/AmountInput';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <ChainSelector />
  <TokenDropdown {tokens} onChange={(token) => {}} />
  <AmountInput />
</Card>
