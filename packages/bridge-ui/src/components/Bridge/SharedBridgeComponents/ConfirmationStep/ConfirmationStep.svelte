<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Hash, Hex } from 'viem';

  import { routingContractsMap } from '$bridgeConfig';
  import { chainConfig } from '$chainConfig';
  import Actions from '$components/Bridge/SharedBridgeComponents/Actions.svelte';
  import {
    allApproved,
    bridgeService,
    destNetwork,
    enteredAmount,
    processingFee,
    recipientAddress,
    selectedNFTs,
    selectedToken,
  } from '$components/Bridge/state';
  import { BridgingStatus } from '$components/Bridge/types';
  import { Icon, type IconType } from '$components/Icon';
  import { successToast } from '$components/NotificationToast';
  import { infoToast, warningToast } from '$components/NotificationToast/NotificationToast.svelte';
  import Spinner from '$components/Spinner/Spinner.svelte';
  import { type ApproveArgs, bridges, type BridgeTransaction, MessageStatus, type NFTApproveArgs } from '$libs/bridge';
  import type { ERC20Bridge } from '$libs/bridge/ERC20Bridge';
  import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
  import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
  import { getBridgeArgs } from '$libs/bridge/getBridgeArgs';
  import { handleBridgeError } from '$libs/bridge/handleBridgeErrors';
  import { BridgePausedError, TransactionTimeoutError } from '$libs/error';
  import { bridgeTxService } from '$libs/storage';
  import { TokenType } from '$libs/token';
  import { getTokenApprovalStatus } from '$libs/token/getTokenApprovalStatus';
  import { isToken } from '$libs/token/isToken';
  import { refreshUserBalance } from '$libs/util/balance';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';
  import { pendingTransactions } from '$stores/pendingTransactions';
  import { theme } from '$stores/theme';

  export let bridgingStatus: BridgingStatus = BridgingStatus.PENDING;

  let bridgeTxHash: Hash;
  let approveTxHash: Hash;

  let bridging: boolean;
  let approving: boolean;
  let checking: boolean;
  let resetting: boolean;

  let icon: IconType;

  $: statusTitle = '';
  $: statusDescription = '';

  const handleBridgeTxHash = async (txHash: Hash) => {
    const currentChain = $connectedSourceChain?.id;

    const destinationChain = $destNetwork?.id;
    const userAccount = $account?.address;
    if (!currentChain || !destinationChain || !userAccount || !$selectedToken) return; //TODO error handling

    const explorer = chainConfig[currentChain]?.blockExplorers?.default.url;

    try {
      await pendingTransactions.add(txHash, currentChain);

      successToast({
        title: $t('bridge.actions.bridge.success.title'),
        message: $t('bridge.actions.bridge.success.message', {
          values: {
            token: $selectedToken.symbol,
          },
        }),
      });
      icon = successIcon;
      bridgingStatus = BridgingStatus.DONE;
      statusTitle = $t('bridge.actions.bridge.success.title');
      statusDescription = $t('bridge.step.confirm.bridge.success.message', {
        values: { url: `${explorer}/tx/${txHash}` },
      });
    } catch (error) {
      if (error instanceof TransactionTimeoutError) {
        handleTimeout(txHash);
      } else {
        handleBridgeError(error as Error);
      }
    }

    const bridgeTx = {
      srcTxHash: txHash,
      from: $account.address,
      amount: $enteredAmount,
      symbol: $selectedToken?.symbol,
      decimals: isToken($selectedToken) ? $selectedToken.decimals : undefined,
      srcChainId: BigInt(currentChain),
      destChainId: BigInt(destinationChain),
      tokenType: $selectedToken?.type,
      msgStatus: MessageStatus.NEW,
      timestamp: Date.now(),
    } as BridgeTransaction;
    bridging = false;

    bridgeTxService.addTxByAddress(userAccount, bridgeTx);
  };

  const handleTimeout = (txHash: Hex) => {
    const currentChain = $connectedSourceChain?.id;
    const explorer = chainConfig[currentChain]?.blockExplorers?.default.url;

    warningToast({
      title: $t('bridge.actions.bridge.timeout.title'),
      message: $t('bridge.actions.bridge.timeout.message', {
        values: {
          url: `${explorer}/tx/${approveTxHash}`,
        },
      }),
    });
    icon = timeoutIcon;
    iconFill = 'fill-warning-sentiment';
    bridgingStatus = BridgingStatus.DONE;
    statusTitle = $t('bridge.actions.bridge.timeout.title');
    statusDescription = $t('bridge.step.confirm.bridge.timeout.message', {
      values: { url: `${explorer}/tx/${txHash}` },
    });
  };

  const handleApproveTxHash = async (txHash: Hash) => {
    const currentChain = $connectedSourceChain?.id;

    const destinationChain = $destNetwork?.id;
    const userAccount = $account?.address;
    if (!currentChain || !destinationChain || !userAccount || !$selectedToken) return; //TODO error handling

    const explorer = chainConfig[currentChain]?.blockExplorers?.default.url;

    infoToast({
      title: $t('bridge.actions.approve.tx.title'),
      message: $t('bridge.actions.approve.tx.message', {
        values: {
          token: $selectedToken.symbol,
          url: `${explorer}/tx/${approveTxHash}`,
        },
      }),
    });

    refreshUserBalance();
    try {
      await pendingTransactions.add(approveTxHash, currentChain);

      statusTitle = $t('bridge.actions.approve.success.title');
      statusDescription = $t('bridge.step.confirm.approve.success.message', {
        values: { url: `${explorer}/tx/${txHash}` },
      });

      await getTokenApprovalStatus($selectedToken);

      successToast({
        title: $t('bridge.actions.approve.success.title'),
        message: $t('bridge.actions.approve.success.message', {
          values: {
            token: $selectedToken.symbol,
          },
        }),
      });
    } catch (error) {
      if (error instanceof TransactionTimeoutError) {
        handleTimeout(txHash);
      } else {
        handleBridgeError(error as Error);
      }
    }
  };

  async function resetApproval() {
    if (!$selectedToken || !$connectedSourceChain || !$destNetwork?.id) return;
    try {
      let tokenAddress = $selectedToken.addresses[$connectedSourceChain.id];
      const type: TokenType = $selectedToken.type;

      const spenderAddress = routingContractsMap[$connectedSourceChain.id][$destNetwork?.id].erc20VaultAddress;
      const walletClient = await getConnectedWallet($connectedSourceChain.id);

      const args: ApproveArgs = { tokenAddress, spenderAddress, wallet: walletClient, amount: 0n };
      approveTxHash = await (bridges[type] as ERC20Bridge).approve(args, true);

      if (approveTxHash) await handleApproveTxHash(approveTxHash);
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  async function approve() {
    isBridgePaused().then((paused) => {
      if (paused) throw new BridgePausedError('Bridge is paused');
    });

    try {
      if (!$selectedToken || !$connectedSourceChain || !$destNetwork?.id) return;
      const type: TokenType = $selectedToken.type;
      const walletClient = await getConnectedWallet($connectedSourceChain.id);

      let tokenAddress = $selectedToken.addresses[$connectedSourceChain.id];

      if (type === TokenType.ERC1155 || type === TokenType.ERC721) {
        const tokenIds = $selectedNFTs && $selectedNFTs.map((nft) => BigInt(nft.tokenId));

        const spenderAddress =
          type === TokenType.ERC1155
            ? routingContractsMap[$connectedSourceChain.id][$destNetwork?.id].erc1155VaultAddress
            : routingContractsMap[$connectedSourceChain.id][$destNetwork?.id].erc721VaultAddress;

        const args: NFTApproveArgs = { tokenIds: tokenIds!, tokenAddress, spenderAddress, wallet: walletClient };
        approveTxHash = await (bridges[type] as ERC721Bridge | ERC1155Bridge).approve(args);
      } else {
        const spenderAddress = routingContractsMap[$connectedSourceChain.id][$destNetwork?.id].erc20VaultAddress;

        const args: ApproveArgs = { tokenAddress, spenderAddress, wallet: walletClient, amount: $enteredAmount };
        approveTxHash = await (bridges[type] as ERC20Bridge).approve(args);
      }

      if (approveTxHash) await handleApproveTxHash(approveTxHash);
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  async function bridge() {
    if (!$bridgeService || !$selectedToken || !$connectedSourceChain || !$destNetwork?.id || !$account?.address) return;
    bridging = true;
    try {
      const walletClient = await getConnectedWallet($connectedSourceChain.id);
      const commonArgs = {
        to: $recipientAddress || $account.address,
        wallet: walletClient,
        srcChainId: $connectedSourceChain.id,
        destChainId: $destNetwork?.id,
        fee: $processingFee,
        tokenObject: $selectedToken,
      };

      const type: TokenType = $selectedToken.type;
      if (type === TokenType.ERC1155 || type === TokenType.ERC721) {
        const tokenIds = $selectedNFTs && $selectedNFTs.map((nft) => nft.tokenId);
        if (!tokenIds) throw new Error('tokenIds not found');
        const bridgeArgs = await getBridgeArgs($selectedToken, $enteredAmount, commonArgs, tokenIds);

        const args = { ...bridgeArgs, tokenIds, tokenObject: $selectedToken };

        bridgeTxHash = await $bridgeService.bridge(args);
      } else {
        const bridgeArgs = await getBridgeArgs($selectedToken, $enteredAmount, commonArgs);

        bridgeTxHash = await $bridgeService.bridge(bridgeArgs);
      }

      if (bridgeTxHash) {
        await handleBridgeTxHash(bridgeTxHash);
      }
    } catch (err) {
      bridging = false;
      console.error(err);
      handleBridgeError(err as Error);
    }
  }
  $: iconFill = '';
  $: approveIcon = `approve-${$theme}` as IconType;
  $: bridgeIcon = `bridge-${$theme}` as IconType;
  $: successIcon = `success-${$theme}` as IconType;
  $: timeoutIcon = `exclamation-circle` as IconType;

  onMount(() => (bridgingStatus = BridgingStatus.PENDING));
</script>

<div class="mt-[30px]">
  <section id="txStatus">
    <div class="flex flex-col justify-content-center items-center">
      {#if bridgingStatus === BridgingStatus.DONE}
        <Icon type={icon} size={160} fillClass={iconFill} />
        <div id="text" class="f-col my-[30px] text-center">
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          <h1>{@html statusTitle}</h1>
          <!-- eslint-disable-next-line svelte/no-at-html-tags -->
          <span class="">{@html statusDescription}</span>
        </div>
      {:else if !$allApproved && !approving && !checking}
        <Icon type={approveIcon} size={160} />
        <div id="text" class="f-col my-[30px] text-center">
          <h1 class="mb-[16px]">{$t('bridge.step.confirm.approve.title')}</h1>
          <span>{$t('bridge.step.confirm.approve.description')}</span>
        </div>
      {:else if checking}
        <Spinner class="!w-[160px] !h-[160px] text-primary-brand" />
        <div id="text" class="f-col my-[30px] text-center">
          <h1 class="mb-[16px]">{$t('bridge.step.confirm.analyzing')}</h1>
          <span>{$t('bridge.step.confirm.checking_status')}</span>
        </div>
      {:else if approving || bridging}
        <Spinner class="!w-[160px] !h-[160px] text-primary-brand" />
        <div id="text" class="f-col my-[30px] text-center">
          <h1 class="mb-[16px]">{$t('bridge.step.confirm.processing')}</h1>
          <span>{$t('bridge.step.confirm.approve.pending')}</span>
        </div>
      {:else if $allApproved && !approving && !bridging}
        <Icon type={bridgeIcon} size={160} />
        <div id="text" class="f-col my-[30px] text-center">
          <h1 class="mb-[16px]">{$t('bridge.step.confirm.approved.title')}</h1>
          {#if $selectedToken?.type === TokenType.ETH}
            <span>{$t('bridge.step.confirm.approved.description_eth')}</span>
          {:else}
            <span>{$t('bridge.step.confirm.approved.description_token')}</span>
          {/if}
        </div>
      {/if}
    </div>
  </section>
  {#if bridgingStatus === BridgingStatus.PENDING}
    <section id="actions" class="f-col w-full">
      <div class="h-sep mb-[30px]" />
      <Actions {approve} {bridge} bind:bridging bind:approving bind:checking bind:resetting {resetApproval} />
    </section>
  {/if}
</div>
