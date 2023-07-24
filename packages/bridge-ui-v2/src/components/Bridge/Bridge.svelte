<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { chains } from '$libs/chain';
  import { ETHToken, tokens } from '$libs/token';
  import type { Account } from '$stores/account';
  import { type Network, network } from '$stores/network';

  import { Amount } from './Amount';
  import { ProcessingFee } from './ProcessingFee';
  import { Recipient } from './Recipient';
  import { destNetwork, selectedToken } from './state';
  import SwitchChainsButton from './SwitchChainsButton.svelte';

  function onNetworkChange(network: Network) {
    if (network && chains.length === 2) {
      // If there are only two chains, the destination chain will be the other one
      const otherChain = chains.find((chain) => chain.id !== network.id);

      if (otherChain) destNetwork.set(otherChain);
    }
  }

  function onAccountChange(account: Account) {
    if (account && account.isConnected && !$selectedToken) {
      $selectedToken = ETHToken;
    } else if (account && account.isDisconnected) {
      $selectedToken = null;
      $destNetwork = null;
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

      <Amount />

      <div class="f-justify-center">
        <SwitchChainsButton />
      </div>

      <div class="space-y-2">
        <ChainSelector label={$t('chain.to')} value={$destNetwork} readOnly />
        <!-- <RecipientInput /> -->
      </div>
    </div>

    <ProcessingFee />

    <div class="h-sep" />

    <Button type="primary" class="px-[28px] py-[14px] rounded-full w-full">
      <span class="body-bold">{$t('bridge.button.bridge')}</span>
    </Button>
  </div>
</Card>

<OnNetwork change={onNetworkChange} />

<OnAccount change={onAccountChange} />
