<script>
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { testERC20Tokens } from '$libs/token';
</script>

<Card class="md:w-[524px]" title={$t('faucet.title')} text={$t('faucet.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector label={$t('chain_selector.currently_on')} />
      <TokenDropdown tokens={testERC20Tokens} />
    </div>

    <Button type="primary" class="px-[28px] py-[14px]">
      <span class="body-bold">{$t('faucet.button.mint')}</span>
    </Button>

    <div class="h-sep" />

    <Alert type="warning" forceColumnFlow>
      {$t('faucet.message.warning')}
    </Alert>
  </div>
</Card>
