<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { Icon } from '$components/Icon';
  import { OnAccount } from '$components/OnAccount';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { ETHToken, tokens } from '$libs/token';
  import type { Account } from '$stores/account';
  import { network, type Network } from '$stores/network';

  import { AmountInput } from './AmountInput';
  import { ProcessingFee } from './ProcessingFee';
  import { RecipientInput } from './RecipientInput';
  import { selectedToken } from './selectedToken';
  import { destNetwork } from './destNetwork';
  import { OnNetwork } from '$components/OnNetwork';
  import { chains } from '$libs/chain';

  function onNetworkChange(network: Network) {
    if (network && chains.length === 2) {
      // If there are only two chains, the destination chain will be the other one
      const otherChain = chains.find((chain) => chain.id !== network.id);

      if (otherChain) destNetwork.set(otherChain);
    }
  }

  function onAccountChange(account: Account) {
    if (account && account?.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    }
  }
</script>

<Card class="md:w-[524px]" title={$t('bridge.title')} text={$t('bridge.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-4">
      <div class="space-y-2">
        <ChainSelector label={$t('chain.from')} value={$network} switchWallet />
        <TokenDropdown {tokens} bind:value={$selectedToken} />
      </div>

      <AmountInput />

      <div class="f-justify-center">
        <button class="f-center rounded-full bg-secondary-icon w-[30px] h-[30px]">
          <Icon type="up-down" />
        </button>
      </div>

      <div class="space-y-2">
        <ChainSelector label={$t('chain.to')} value={$destNetwork} readOnly />
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

<OnNetwork change={onNetworkChange} />

<OnAccount change={onAccountChange} />
