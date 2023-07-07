<script lang="ts">
  import type { Chain } from '@wagmi/core';
  import { t } from 'svelte-i18n';

  import AmountInput from '$components/AmountInput';
  import Button from '$components/Button/Button.svelte';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import Icon from '$components/Icon/Icon.svelte';
  import { ProcessingFee } from '$components/ProcessingFee';
  import { RecipientInput } from '$components/RecipientInput';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { web3modal } from '$libs/connect';
  import { tokens } from '$libs/token';
  import { destChain, srcChain } from '$stores/network';

  function onSrcChainChange(chain: Chain) {
    if (chain !== $srcChain) {
      srcChain.set(chain);

      // Let's not forget to update the default chain
      // in web3modal. Unfortunately we have to maintain
      // two states here due to the fact that the user
      // can change the network from the UI.
      web3modal.setDefaultChain(chain);
    }
  }

  function onDestChainChange(chain: Chain) {
    if (chain !== $destChain) {
      destChain.set(chain);
    }
  }
</script>

<Card class="md:w-[524px]" title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-4">
      <div class="space-y-2">
        <ChainSelector label={$t('chain.from')} value={$srcChain} onChange={onSrcChainChange} />
        <TokenDropdown {tokens} />
      </div>

      <AmountInput />

      <div class="f-justify-center">
        <button class="f-center rounded-full bg-secondary-icon w-[30px] h-[30px]">
          <Icon type="up-down" />
        </button>
      </div>

      <div class="space-y-2">
        <ChainSelector label={$t('chain.to')} value={$destChain} onChange={onDestChainChange} />
        <RecipientInput />
      </div>
    </div>

    <ProcessingFee />

    <div class="h-sep" />

    <Button type="primary" class="px-[28px] py-[14px]">
      <span class="body-bold">{$t('bridge.button.bridge')}</span>
    </Button>
  </div>
</Card>
