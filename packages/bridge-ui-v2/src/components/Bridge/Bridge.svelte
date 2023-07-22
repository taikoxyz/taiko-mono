<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { successToast } from '$components/NotificationToast';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { PUBLIC_L1_EXPLORER_URL } from '$env/static/public';
  import { bridges } from '$libs/bridge';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import { chainContractsMap, chains } from '$libs/chain';
  import { ETHToken, getAddress, tokens } from '$libs/token';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import type { Account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import Amount from './Amount.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import { destNetwork, enteredAmount, processingFee, selectedToken } from './state';
  import SwitchChainsButton from './SwitchChainsButton.svelte';
  import Validator from './Validator.svelte';

  let validator: Validator;

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

  async function approve() {
    if (!$selectedToken || !$network || !$destNetwork) return;

    const erc20Bridge = bridges.ERC20 as ERC20Bridge;

    try {
      const walletClient = await getConnectedWallet($network.id);

      const tokenAddress = await getAddress({
        token: $selectedToken,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
      });

      if (!tokenAddress) {
        throw new Error('token address not found');
      }

      const spenderAddress = chainContractsMap[$network.id].tokenVaultAddress;

      const txHash = await erc20Bridge.approve({
        tokenAddress,
        spenderAddress,
        amount: $enteredAmount,
        wallet: walletClient,
      });

      successToast(
        $t('bridge.approve_tx', {
          values: {
            token: $selectedToken.symbol,
            url: `${PUBLIC_L1_EXPLORER_URL}/tx/${txHash}`,
          },
        }),
        true,
      );

      await pendingTransactions.add(txHash, $network.id);

      // Let's run the validation again, which will update UI state
      validator.validate();
    } catch (err) {
      console.error(err);
    }
  }

  async function bridge() {
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

<Validator bind:this={validator} />
