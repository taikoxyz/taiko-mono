<script>
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
  import AmountInput from '$components/AmountInput';
  import { Button } from '$components/Button';
  import { ChainSelector } from '$components/ChainSelector';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <ChainSelector />
  <TokenDropdown {tokens} onChange={(token) => {}} />
  <AmountInput />
</Card>
