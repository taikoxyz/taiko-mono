<script lang="ts">
  import { writable } from 'svelte/store';
  import { t } from 'svelte-i18n';

  import { Alert } from '$components/Alert';
  import AddressInput from '$components/Bridge/AddressInput/AddressInput.svelte';
  import NftIdInput from '$components/Bridge/NftIdInput/NftIdInput.svelte';
  import { Button } from '$components/Button';
  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { chains } from '$libs/chain';
  import { detectContractType, ETHToken, fetchERC721Images, fetchERC1155Images, type Token, tokens } from '$libs/token';
  import type { Account } from '$stores/account';

  import { activeTab } from '$stores/bridgetabs';

  import Erc20Bridge from './ERC20Bridge.svelte';

  import { type Network, network } from '$stores/network';

  import { ProcessingFee } from './ProcessingFee';
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

<Card class="md:w-[524px]" title={$t('bridge.erc20.title')} text={$t('bridge.subtitle')}>
  <div class="space-y-[35px]">
    <div class="space-y-4">
      <div class="space-y-2">
        <ChainSelector label={$t('chain.from')} value={$network} switchWallet />
        <TokenDropdown {tokens} bind:value={$selectedToken} />
      </div>

      <AmountInput />

      <div class="f-justify-center">
        <SwitchChainsButton />
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
