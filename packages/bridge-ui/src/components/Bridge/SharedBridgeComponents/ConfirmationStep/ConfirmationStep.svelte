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
  import { BridgePausedError, ReceiptUnavailableError, TransactionTimeoutError } from '$libs/error';
  import { recordBridgeTx } from '$libs/storage/recordBridgeTx';
  import { TokenType } from '$libs/token';
  import { ApprovalStatus } from '$libs/token/getTokenApprovalStatus';
  import { isToken } from '$libs/token/isToken';
  import { waitForApprovalStatus } from '$libs/token/waitForApprovalStatus';
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

    try {
      if (!currentChain || !destinationChain || !userAccount || !$selectedToken) return; //TODO error handling

      const explorer = chainConfig[currentChain]?.blockExplorers?.default.url;

      const bridgeTx = {
        srcTxHash: txHash,
        from: userAccount,
        amount: $enteredAmount,
        symbol: $selectedToken?.symbol,
        decimals: isToken($selectedToken) ? $selectedToken.decimals : undefined,
        srcChainId: BigInt(currentChain),
        destChainId: BigInt(destinationChain),
        tokenType: $selectedToken?.type,
        msgStatus: MessageStatus.NEW,
        // Needed later to decide whether the manual "try claim" entry applies
        processingFee: $processingFee,
        timestamp: Date.now(),
      } as BridgeTransaction;

      try {
        // The only thing this try classifies is the wait: anything else in here would
        // reach the catch below as if the transaction itself had failed
        await pendingTransactions.add(txHash, currentChain);
      } catch (error) {
        if (waitGaveUp(error)) {
          // Only the wait gave up - a timeout, or a receipt that could not be read. The
          // transaction may still confirm, so keep it in the local history
          recordBridgeTx(userAccount, bridgeTx);
          handleTimeout(txHash);
        } else {
          // Reverted: recording it would leave a phantom pending transaction
          handleBridgeError(error as Error);
        }
        return;
      }

      // Confirmed on-chain: record it in the local history
      recordBridgeTx(userAccount, bridgeTx);

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
    } finally {
      bridging = false;
    }
  };

  /**
   * @dev Whether the receipt wait gave up rather than the transaction failing.
   *
   *      Only a receipt that came back reverted is a failure. A wait that timed out, or an
   *      RPC that could not be read, says nothing about a transaction still in the
   *      mempool - and dropping it from the local history on that basis loses it until the
   *      relayer indexes it.
   *
   * @param error What pendingTransactions.add rejected with
   * @return gaveUp_ Whether the transaction's fate is simply unknown
   */
  const waitGaveUp = (error: unknown) =>
    // Named rather than inferred from "not a failure". These two are the only rejections
    // that mean the wait gave up; anything else here is unexpected, and reporting it as
    // "your transaction may still confirm" would bury a real error behind a reassurance.
    error instanceof TransactionTimeoutError || error instanceof ReceiptUnavailableError;

  const handleTimeout = (txHash: Hex) => {
    const currentChain = $connectedSourceChain?.id;
    const explorer = chainConfig[currentChain]?.blockExplorers?.default.url;

    warningToast({
      title: $t('bridge.actions.bridge.timeout.title'),
      message: $t('bridge.actions.bridge.timeout.message', {
        values: {
          // The timed-out transaction itself, not the (possibly absent) approval tx
          url: `${explorer}/tx/${txHash}`,
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

  /**
   * @param txHash The approval or reset transaction
   * @param pendingStatus The status that still means "not seen yet" for this transition -
   *        an approval waits off APPROVAL_REQUIRED, an allowance reset waits off
   *        RESET_REQUIRED
   */
  const handleApproveTxHash = async (
    txHash: Hash,
    pendingStatus: ApprovalStatus = ApprovalStatus.APPROVAL_REQUIRED,
  ) => {
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
    // A reverted approval has no pending change for the status re-read to wait for, so
    // retrying it only keeps the spinner up after the failure is already on screen
    let approvalFailed = false;
    try {
      await pendingTransactions.add(approveTxHash, currentChain);

      statusTitle = $t('bridge.actions.approve.success.title');
      statusDescription = $t('bridge.step.confirm.approve.success.message', {
        values: { url: `${explorer}/tx/${txHash}` },
      });

      successToast({
        title: $t('bridge.actions.approve.success.title'),
        message: $t('bridge.actions.approve.success.message', {
          values: {
            token: $selectedToken.symbol,
          },
        }),
      });
    } catch (error) {
      if (waitGaveUp(error)) {
        // A wait that gave up may still confirm, so the status is still worth polling
        handleTimeout(txHash);
      } else {
        approvalFailed = true;
        handleBridgeError(error as Error);
      }
    } finally {
      // The buttons are driven off this read, so it has to happen whatever the wait above
      // did: a timed-out wait does not mean the approval failed, and leaving the status
      // stale is what forced a page reload before Bridge would enable.
      try {
        await waitForApprovalStatus($selectedToken, approvalFailed ? { attempts: 1 } : { pendingStatus });
      } catch (error) {
        console.error('Could not refresh the approval status', error);
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

      // A reset moves RESET_REQUIRED -> APPROVAL_REQUIRED, the opposite of an approval
      if (approveTxHash) await handleApproveTxHash(approveTxHash, ApprovalStatus.RESET_REQUIRED);
    } catch (err) {
      console.error(err);
      handleBridgeError(err as Error);
    }
  }

  async function approve() {
    try {
      if (!$selectedToken || !$connectedSourceChain || !$destNetwork?.id) return;
      // Scoped to the chain the approval is for. Unscoped, a pause on any other configured
      // chain refused an approval that has nothing to do with it
      if (await isBridgePaused($connectedSourceChain.id)) throw new BridgePausedError('Bridge is paused');
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
