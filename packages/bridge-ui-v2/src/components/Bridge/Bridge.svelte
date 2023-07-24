<script lang="ts">
  import { t } from 'svelte-i18n';
  import { UserRejectedRequestError } from 'viem';

  import { Card } from '$components/Card';
  import { ChainSelector } from '$components/ChainSelector';
  import { successToast, warningToast } from '$components/NotificationToast';
  import { errorToast, infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import { OnAccount } from '$components/OnAccount';
  import { OnNetwork } from '$components/OnNetwork';
  import { TokenDropdown } from '$components/TokenDropdown';
  import { PUBLIC_L1_EXPLORER_URL } from '$env/static/public';
  import { type BridgeArgs, bridges, type ERC20BridgeArgs, type ETHBridgeArgs } from '$libs/bridge';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import { chainContractsMap, chains } from '$libs/chain';
  import { ApproveError, NoAllowanceRequiredError, SendERC20Error, SendMessageError } from '$libs/error';
  import { ETHToken, getAddress, isDeployedCrossChain, tokens, TokenType } from '$libs/token';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { type Account, account } from '$stores/account';
  import { type Network, network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from './Actions.svelte';
  import Amount from './Amount.svelte';
  import { ProcessingFee } from './ProcessingFee';
  import Recipient from './Recipient.svelte';
  import { bridgeService, destNetwork, enteredAmount, processingFee, recipientAddress, selectedToken } from './state';
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

      infoToast(
        $t('bridge.approve.tx', {
          values: {
            token: $selectedToken.symbol,
            url: `${PUBLIC_L1_EXPLORER_URL}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('bridge.approve.success', {
          values: {
            token: $selectedToken.symbol,
          },
        }),
      );

      // Let's run the validation again, which will update UI
      amountComponent.validateAmount();
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast($t('bridge.approve.rejected'));
          break;
        case err instanceof NoAllowanceRequiredError:
          errorToast($t('bridge.approve.no_allowance_required'));
          break;
        case err instanceof ApproveError:
          // TODO: see contract for all possible errors
          errorToast($t('bridge.approve.error'));
          break;
        default:
          errorToast($t('bridge.approve.unknown_error'));
      }
    }
  }

  async function bridge() {
    if (!$bridgeService || !$selectedToken || !$network || !$destNetwork || !$account?.address) return;

    try {
      const walletClient = await getConnectedWallet($network.id);

      // Common arguments for both ETH and ERC20 bridges
      let bridgeArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $network.id,
        destChainId: $destNetwork.id,
        amount: $enteredAmount,
        processingFee: $processingFee,
      } as BridgeArgs;

      switch ($selectedToken.type) {
        case TokenType.ETH: {
          // Specific arguments for ETH bridge:
          // - bridgeAddress
          const bridgeAddress = chainContractsMap[$network.id].bridgeAddress;
          bridgeArgs = { ...bridgeArgs, bridgeAddress } as ETHBridgeArgs;
          break;
        }

        case TokenType.ERC20: {
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
          break;
        }

        default:
          throw new Error('invalid token type');
      }

      const txHash = await $bridgeService.bridge(bridgeArgs);

      infoToast(
        $t('bridge.bridge.tx', {
          values: {
            token: $selectedToken.symbol,
            url: `${PUBLIC_L1_EXPLORER_URL}/tx/${txHash}`,
          },
        }),
      );

      await pendingTransactions.add(txHash, $network.id);

      successToast(
        $t('bridge.bridge.success', {
          values: {
            network: $destNetwork.name,
          },
        }),
      );

      // Reset the form
      amountComponent.clearAmount();
      recipientComponent.clearRecipient();
      processingFeeComponent.resetProcessingFee();

      // Update balance after bridging
      amountComponent.updateBalance();
    } catch (err) {
      console.error(err);

      switch (true) {
        case err instanceof UserRejectedRequestError:
          warningToast($t('bridge.bridge.rejected'));
          break;
        case err instanceof SendMessageError:
          // TODO: see contract for all possible errors
          errorToast($t('bridge.bridge.send_message_error'));
          break;
        case err instanceof SendERC20Error:
          // TODO: see contract for all possible errors
          errorToast($t('bridge.bridge.send_erc20_error'));
          break;
        default:
          errorToast($t('bridge.approve.unknown_error'));
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

    <Amount bind:this={amountComponent} />

    <Recipient bind:this={recipientComponent} />

    <ProcessingFee bind:this={processingFeeComponent} />

    <div class="h-sep" />

    <Actions {approve} {bridge} />
  </div>
</Card>

<OnNetwork change={onNetworkChange} />

<OnAccount change={onAccountChange} />
