<script>
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { Alert } from '$components/Alert';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { testERC20Tokens } from '$libs/token';
  import { Button } from '$components/Button';
</script>

<Card title={$t('faucet.title')} text={$t('faucet.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-2">
      <ChainSelector label={$t('faucet.currently_on')} />
      <TokenDropdown tokens={testERC20Tokens} />
    </div>

    <Button type="primary" class="px-[28px] py-[14px]">
      <span class="body-bold">{$t('faucet.mint_button')}</span>
    </Button>

    <div class="h-sep" />

    <Alert type="warning" forceColumnFlow>
      {$t('faucet.warning_message')}
    </Alert>
  </div>
</Card>
