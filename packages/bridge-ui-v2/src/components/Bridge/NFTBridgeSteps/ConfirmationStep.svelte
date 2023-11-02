<script lang="ts">
  import type { Hash } from '@wagmi/core';
  import { t } from 'svelte-i18n';
  import { getAddress } from 'viem';

  import { routingContractsMap } from '$bridgeConfig';
  import { chainConfig } from '$chainConfig';
  import { Icon } from '$components/Icon';
  import { successToast } from '$components/NotificationToast';
  import { infoToast } from '$components/NotificationToast/NotificationToast.svelte';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { bridges, type BridgeTransaction, MessageStatus, type NFTApproveArgs } from '$libs/bridge';
  import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
  import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
  import { getBridgeArgs } from '$libs/bridge/getBridgeArgs';
  import { handleBridgeError } from '$libs/bridge/handleBridgeErrors';
  import { bridgeTxService } from '$libs/storage';
  import { TokenType } from '$libs/token';
  import { getCrossChainAddress } from '$libs/token/getCrossChainAddress';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { account } from '$stores/account';
  import { network } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';

  import Actions from '../Actions.svelte';
  import {
    bridgeService,
    destNetwork,
    enteredAmount,
    processingFee,
    recipientAddress,
    selectedNFTs,
    selectedToken,
  } from '../state';

  export let bridgingStatus: 'pending' | 'done' = 'pending';
  let bridgeTxHash: Hash;

  let actionsComponent: Actions;
  let allTokensApproved: boolean;
  let bridging: boolean;
  let approving: boolean;

  $: statusTitle = 'Success!';
  $: statusDescription = '';

  const handleBridgeTxHash = (txHash: Hash) => {
    const currentChain = $network?.id;

    const destinationChain = $destNetwork?.id;
    const userAccount = $account?.address;
    if (!currentChain || !destinationChain || !userAccount) return; //TODO error handling

    const explorer = chainConfig[currentChain].urls.explorer;
    statusTitle = $t('bridge.actions.bridge.tx.title');
    statusDescription = $t('bridge.actions.bridge.tx.message', {
      values: {
        url: `${explorer}/tx/${txHash}`,
      },
    });

    pendingTransactions.add(txHash, currentChain).then(() => {
      bridgingStatus = 'done';
      statusTitle = $t('bridge.actions.bridge.success.title');
      statusDescription = $t('bridge.actions.bridge.success.message');
      const bridgeTx = {
        hash: txHash,
        from: $account.address,
        amount: $enteredAmount,
        symbol: $selectedToken?.symbol,
        decimals: $selectedToken?.decimals,
        srcChainId: BigInt(currentChain),
        destChainId: BigInt(destinationChain),
        tokenType: $selectedToken?.type,
        status: MessageStatus.NEW,
        timestamp: Date.now(),
      } as BridgeTransaction;
      bridging = false;

      bridgeTxService.addTxByAddress(userAccount, bridgeTx);
    });
  };

  async function approve() {
    try {
      if (!$selectedToken || !$network || !$destNetwork?.id) return;
      const type: TokenType = $selectedToken.type;
      const walletClient = await getConnectedWallet($network.id);
      let tokenAddress = await getAddress($selectedToken.addresses[$network.id]);

      if (!tokenAddress) {
        const crossChainAddress = await getCrossChainAddress({
          token: $selectedToken,
          srcChainId: $network.id,
          destChainId: $destNetwork.id,
        });
        if (!crossChainAddress) throw new Error('cross chain address not found');
        tokenAddress = crossChainAddress;
      }
      if (!tokenAddress) {
        throw new Error('token address not found');
      }
      const tokenIds = $selectedNFTs && $selectedNFTs.map((nft) => BigInt(nft.tokenId));

      let txHash: Hash;

      const spenderAddress =
        type === TokenType.ERC1155
          ? routingContractsMap[$network.id][$destNetwork?.id].erc1155VaultAddress
          : routingContractsMap[$network.id][$destNetwork?.id].erc721VaultAddress;

      const args: NFTApproveArgs = { tokenIds: tokenIds!, tokenAddress, spenderAddress, wallet: walletClient };
      txHash = await (bridges[type] as ERC721Bridge | ERC1155Bridge).approve(args);

      const { explorer } = chainConfig[$network.id].urls;

      if (txHash)
        infoToast({
          title: $t('bridge.actions.approve.tx.title'),
          message: $t('bridge.actions.approve.tx.message', {
            values: {
              token: $selectedToken.symbol,
              url: `${explorer}/tx/${txHash}`,
            },
          }),
        });

      await pendingTransactions.add(txHash, $network.id);

      actionsComponent.checkTokensApproved();

      successToast({
        title: $t('bridge.actions.approve.success.title'),
        message: $t('bridge.actions.approve.success.message', {
          values: {
            token: $selectedToken.symbol,
          },
        }),
      });
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  async function bridge() {
    if (!$bridgeService || !$selectedToken || !$network || !$destNetwork?.id || !$account?.address) return;
    bridging = true;
    try {
      const walletClient = await getConnectedWallet($network.id);
      const commonArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $network.id,
        destChainId: $destNetwork?.id,
        fee: $processingFee,
      };

      const tokenIds = $selectedNFTs && $selectedNFTs.map((nft) => nft.tokenId);
      if (!tokenIds) throw new Error('tokenIds not found');

      const bridgeArgs = await getBridgeArgs($selectedToken, $enteredAmount, commonArgs, tokenIds);

      const args = { ...bridgeArgs, tokenIds };

      bridgeTxHash = await $bridgeService.bridge(args);

      if (bridgeTxHash) {
        handleBridgeTxHash(bridgeTxHash);
      }
    } catch (err) {
      bridging = false;
      console.error(err);
      handleBridgeError(err as Error);
    }
  }
</script>

<div class="mt-[30px]">
  <section id="txStatus">
    <div class="flex flex-col justify-content-center items-center">
      {#if bridgingStatus === 'done'}
        <Icon type="check-circle" size={160} fillClass="fill-positive-sentiment" />
        <div id="text" class="f-col my-[30px] text-center">
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          <h1>{@html statusTitle}</h1>
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          <span class="">{@html statusDescription}</span>
        </div>
      {:else if !allTokensApproved}
        <Icon type="info-circle" size={160} fillClass="fill-blue-400" />
        <div id="text" class="f-col my-[30px] text-center">
          <h1 class="mb-[16px]">Approve tokens</h1>
          <span>Before you can bridge, you need to approve your tokens</span>
        </div>
      {:else if bridging || approving}
        <Spinner class="!w-[160px] !h-[160px] text-primary-brand" />
        <div id="text" class="f-col my-[30px] text-center">
          <span>Please wait for your transaction to be picked up</span>
        </div>
      {:else}
        <Icon type="info-circle" size={160} fillClass="fill-blue-400" />
        <div id="text" class="f-col my-[30px] text-center">
          <h1 class="mb-[16px]">Bridge your tokens</h1>
          <span>Your token are approved! You can now bridge them by clicking the button below</span>
        </div>
      {/if}
    </div>
  </section>
  {#if bridgingStatus !== 'done'}
    <section id="actions" class="f-col w-full">
      <div class="h-sep mb-[30px]" />
      <Actions
        bind:this={actionsComponent}
        {approve}
        {bridge}
        oldStyle={false}
        bind:allTokensApproved
        bind:bridging
        bind:approving />
    </section>
  {/if}
</div>
