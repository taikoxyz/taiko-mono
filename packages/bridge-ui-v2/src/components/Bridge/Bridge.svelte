<script lang="ts">
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { PUBLIC_L1_EXPLORER_URL } from '$env/static/public';
  import { type Bridge, type BridgeArgs, bridges, type ERC20BridgeArgs, type ETHBridgeArgs } from '$libs/bridge';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import type { ETHBridge } from '$libs/bridge/ETHBridge';
  import { chainContractsMap, chains } from '$libs/chain';
  import { ETHToken, getAddress, isDeployedCrossChain, isETH, tokens } from '$libs/token';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import Amount from './Amount.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import { destNetwork, enteredAmount, processingFee, recipientAddress, selectedToken } from './state';
  import SwitchChainsButton from './SwitchChainsButton.svelte';

  let amountComponent: Amount;
  let recipientComponent: Recipient;
  let processingFeeComponent: ProcessingFee;

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

      // Let's run the validation again, which will update UI
      amountComponent.validate();
    } catch (err) {
      console.error(err);

      if (err instanceof UserRejectedRequestError) {
        warningToast($t('messages.network.rejected'));
      }
    }
  }

  async function bridge() {
    if (!$selectedToken || !$network || !$destNetwork || !$account?.address) return;

    try {
      const walletClient = await getConnectedWallet($network.id);

      let bridge: Bridge;

      // Common arguments for both ETH and ERC20 bridges
      let bridgeArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
        amount: $enteredAmount,
        processingFee: $processingFee,
      } as BridgeArgs;

      if (isETH($selectedToken)) {
        bridge = bridges.ETH as ETHBridge;

        // Specific arguments for ETH bridge:
        // - bridgeAddress
        const bridgeAddress = chainContractsMap[$network.id].bridgeAddress;
        bridgeArgs = { ...bridgeArgs, bridgeAddress } as ETHBridgeArgs;
      } else {
        bridge = bridges.ERC20 as ERC20Bridge;

        // Specific arguments for ERC20 bridge
        // - tokenAddress
        // - tokenVaultAddress
        // - isTokenAlreadyDeployed
        const tokenAddress = await getAddress({
          token: $selectedToken,
          srcChainId: $network.id,
          destChainId: $destNetwork.id,
        });

        if (!tokenAddress) {
          throw new Error('token address not found');
        }

        const tokenVaultAddress = chainContractsMap[$network.id].tokenVaultAddress;

        const isTokenAlreadyDeployed = await isDeployedCrossChain({
          token: $selectedToken,
          srcChainId: $network.id,
          destChainId: $destNetwork.id,
        });

        bridgeArgs = {
          ...bridgeArgs,
          tokenAddress,
          tokenVaultAddress,
          isTokenAlreadyDeployed,
        } as ERC20BridgeArgs;
      }

      const txHash = await bridge.bridge(bridgeArgs);

      successToast(
        $t('bridge.bridge_tx', {
          values: {
            token: $selectedToken.symbol,
            url: `${PUBLIC_L1_EXPLORER_URL}/tx/${txHash}`,
          },
        }),
        true,
      );

      await pendingTransactions.add(txHash, $network.id);

      // Reset the form
      amountComponent.clearAmount();
      recipientComponent.clearRecipient();
      processingFeeComponent.resetProcessingFee();

      // Update balance
      amountComponent.updateBalance();
    } catch (err) {
      console.error(err);

      if (err instanceof UserRejectedRequestError) {
        warningToast($t('messages.network.rejected'));
      }
    }
  }
</script>

<Card class="md:w-[524px]" title={$t('bridge.title')} text={$t('bridge.description')}>
  <div class="space-y-[35px]">
    <div class="f-between-center gap-4">
      <ChainSelector class="flex-1" value={$network} switchWallet />

      <SwitchChainsButton />

      <!-- TODO: should not be readOnly when multiple layers -->
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
