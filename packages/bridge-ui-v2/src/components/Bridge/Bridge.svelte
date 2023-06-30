<script>
  import { t } from 'svelte-i18n';

  import AmountInput from '$components/AmountInput';
  import Button from '$components/Button/Button.svelte';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import Icon from '$components/Icon/Icon.svelte';
  import { ProcessingFee } from '$components/ProcessingFee';
  import { RecipientInput } from '$components/RecipientInput';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { tokens } from '$libs/token';
</script>

<Card title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <div class="space-y-4">
    <div class="space-y-2">
      <ChainSelector label={$t('chain.from')} />
      <TokenDropdown {tokens} />
    </div>

    <AmountInput />

    <div class="f-justify-center">
      <button>
        <Icon type="up-down-circle" size={36} />
      </button>
    </div>

    <div class="space-y-2">
      <ChainSelector label={$t('chain.to')} />
      <RecipientInput />
    </div>

    <ProcessingFee />
  </div>

  <div class="h-sep my-[35px]" />

  <Button type="primary" class="px-[28px] py-[14px]">
    <span class="body-bold">{$t('bridge.bridge_button')}</span>
  </Button>
</Card>
