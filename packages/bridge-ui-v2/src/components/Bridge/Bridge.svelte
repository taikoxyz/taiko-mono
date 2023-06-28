<script>
  import { t } from 'svelte-i18n';

  import AmountInput from '$components/AmountInput';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { RecipientInput } from '$components/RecipientInput';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
  import { ProcessingFee } from '$components/ProcessingFee';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <div class="space-y-2">
    <ChainSelector label="From" />
    <TokenDropdown {tokens} />
  </div>

  <AmountInput label="Amount" />

  <RecipientInput />
  <ProcessingFee />
</Card>
