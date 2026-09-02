<script lang="ts">
  import { onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import type { Address, Hash, Hex } from 'viem';

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
  import { isSlowL1Bridging } from '$libs/chain';
  import { BridgePausedError, ReceiptUnavailableError, TransactionTimeoutError } from '$libs/error';
  import { recordBridgeTx } from '$libs/storage/recordBridgeTx';
  import { TokenType } from '$libs/token';
  import { ApprovalStatus } from '$libs/token/getTokenApprovalStatus';
  import { isToken } from '$libs/token/isToken';
  import type { NFT, Token } from '$libs/token/types';
  import { waitForApprovalStatus } from '$libs/token/waitForApprovalStatus';
  import { refreshUserBalance } from '$libs/util/balance';
  import { isBridgePaused } from '$libs/util/checkForPausedContracts';
  import { escapeHtml } from '$libs/util/escapeHtml';
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

  /**
   * What the wallet was asked to sign, captured before the prompt opens.
   *
   * The prompt can sit open for minutes, and a wallet that switches account or network
   * meanwhile moves the stores with it. Everything the local record, the receipt wait and
   * the confirmation copy need is read from here rather than from the stores, so the entry
   * lands in the sender's history and describes the transaction that was signed.
   */
  type SentBridge = {
    from: Address;
    srcChainId: number;
    destChainId: number;
    destChainName: string;
    token: Token | NFT;
    amount: bigint;
    fee: bigint;
  };

  const handleBridgeTxHash = async (txHash: Hash, sent: SentBridge) => {
    try {
      const explorer = chainConfig[sent.srcChainId]?.blockExplorers?.default.url;

      const bridgeTx = {
        srcTxHash: txHash,
        from: sent.from,
        amount: sent.amount,
        symbol: sent.token.symbol,
        decimals: isToken(sent.token) ? sent.token.decimals : undefined,
        srcChainId: BigInt(sent.srcChainId),
        destChainId: BigInt(sent.destChainId),
        tokenType: sent.token.type,
        msgStatus: MessageStatus.NEW,
        // Needed later to decide whether the manual "try claim" entry applies
        processingFee: sent.fee,
        timestamp: Date.now(),
      } as BridgeTransaction;

      // The wallet may have repriced the transaction, in which case this is the hash that
      // mined and the one the local record must carry - the original never will
      let minedTxHash: Hash = txHash;
      try {
        // The only thing this try classifies is the wait: anything else in here would
        // reach the catch below as if the transaction itself had failed
        const receipt = await pendingTransactions.add(txHash, sent.srcChainId);
        minedTxHash = receipt.transactionHash;
      } catch (error) {
        if (waitGaveUp(error)) {
          // Only the wait gave up - a timeout, or a receipt that could not be read. The
          // transaction may still confirm, so keep it in the local history
          recordBridgeTx(sent.from, bridgeTx);
          handleTimeout(txHash, sent.srcChainId);
        } else {
          // Reverted: recording it would leave a phantom pending transaction
          handleBridgeError(error as Error);
        }
        return;
      }

      // Confirmed on-chain: record it in the local history
      recordBridgeTx(sent.from, { ...bridgeTx, srcTxHash: minedTxHash });

      // The funds are claimed on the destination, which is only Taiko in one direction. The
      // name is interpolated into a string rendered with {@html}, so it is escaped like every
      // other interpolated value
      successToast({
        title: $t('bridge.actions.bridge.success.title'),
        message: $t('bridge.actions.bridge.success.message', { values: { chain: escapeHtml(sent.destChainName) } }),
      });
      icon = successIcon;
      bridgingStatus = BridgingStatus.DONE;
      statusTitle = $t('bridge.actions.bridge.success.title');
      // An L2 -> L1 transfer is claimable hours later, not in a few minutes. The review step
      // warned about that one screen earlier, and this screen has to agree with it
      statusDescription = $t(
        isSlowL1Bridging(sent.destChainId)
          ? 'bridge.step.confirm.bridge.success.message_slow_l1'
          : 'bridge.step.confirm.bridge.success.message',
        { values: { url: `${explorer}/tx/${minedTxHash}` } },
      );
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

  /**
   * @dev Reports a receipt wait that gave up: the transaction may still confirm, so the
   *      user is pointed at the explorer rather than told it failed.
   * @param txHash The transaction whose wait gave up
   * @param chainId The chain it was sent on - passed in, since the wallet may have moved on
   */
  const handleTimeout = (txHash: Hex, chainId: number) => {
    const explorer = chainConfig[chainId]?.blockExplorers?.default.url;

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
          token: escapeHtml($selectedToken.symbol),
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
            token: escapeHtml($selectedToken.symbol),
          },
        }),
      });
    } catch (error) {
      if (waitGaveUp(error)) {
        // A wait that gave up may still confirm, so the status is still worth polling
        handleTimeout(txHash, currentChain);
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
      // Read once, here, and used for both the transaction and its record: see SentBridge
      const sent: SentBridge = {
        from: $account.address,
        srcChainId: $connectedSourceChain.id,
        destChainId: $destNetwork.id,
        destChainName: $destNetwork.name,
        token: $selectedToken,
        amount: $enteredAmount,
        fee: $processingFee,
      };
      // Derived from the token, so read in the same breath as it: building the arguments goes
      // over the network, and a token switch during that wait would otherwise move the
      // dispatch to another token's bridge while the arguments still described this one
      const service = $bridgeService;
      const commonArgs = {
        to: $recipientAddress || sent.from,
        wallet: walletClient,
        srcChainId: sent.srcChainId,
        destChainId: sent.destChainId,
        fee: sent.fee,
        tokenObject: sent.token,
      };

      const type: TokenType = sent.token.type;
      if (type === TokenType.ERC1155 || type === TokenType.ERC721) {
        const tokenIds = $selectedNFTs && $selectedNFTs.map((nft) => nft.tokenId);
        if (!tokenIds) throw new Error('tokenIds not found');
        const bridgeArgs = await getBridgeArgs(sent.token, sent.amount, commonArgs, tokenIds);

        const args = { ...bridgeArgs, tokenIds, tokenObject: sent.token };

        bridgeTxHash = await service.bridge(args);
      } else {
        const bridgeArgs = await getBridgeArgs(sent.token, sent.amount, commonArgs);

        bridgeTxHash = await service.bridge(bridgeArgs);
      }

      if (bridgeTxHash) {
        await handleBridgeTxHash(bridgeTxHash, sent);
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
