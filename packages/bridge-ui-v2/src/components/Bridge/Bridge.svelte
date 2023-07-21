<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { chains } from '$libs/chain';
  import { ETHToken, tokens } from '$libs/token';
  import type { Account } from '$stores/account';
  import { type Network, network } from '$stores/network';

  import Actions from './Actions.svelte';
  import Amount from './Amount.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
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

  function approve() {
    // TODO
  }

  function bridge() {
    // TODO
  }
</script>

<Card class="md:w-[524px]" title={$t('bridge.title')} text={$t('bridge.description')}>
  <div class="space-y-[35px]">
    <div class="f-between-center gap-4">
      <ChainSelector class="flex-1" value={$network} switchWallet />

      <SwitchChainsButton />

      <ChainSelector class="flex-1" value={$destNetwork} readOnly />
    </div>

    <TokenDropdown {tokens} bind:value={$selectedToken} />

    <Amount />

    <Recipient />

    <ProcessingFee />

    <div class="h-sep" />

    <Actions {approve} {bridge} />
  </div>
</Card>

<OnNetwork change={onNetworkChange} />

<OnAccount change={onAccountChange} />
