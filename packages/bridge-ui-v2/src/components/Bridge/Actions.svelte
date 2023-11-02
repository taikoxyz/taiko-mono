<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { bridges, ContractType, type RequireApprovalArgs } from '$libs/bridge';
  import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
  import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
  import { getContractAddressByType } from '$libs/bridge/getContractAddressByType';
  import { type NFT, TokenType } from '$libs/token';
  import { checkOwnershipOfNFT } from '$libs/token/checkOwnership';
  import { getConnectedWallet } from '$libs/util/getConnectedWallet';
  import { account, network } from '$stores';

  import {
    computingBalance,
    destNetwork,
    enteredAmount,
    errorComputingBalance,
    insufficientAllowance,
    insufficientBalance,
    recipientAddress,
    selectedToken,
    tokenBalance,
    validatingAmount,
  } from './state';

  export let approve: () => Promise<void>;
  export let bridge: () => Promise<void>;

  export let oldStyle = true; //TODO: remove this

  export let approving = false;
  export let bridging = false;

  export let allTokensApproved = false;

  function onApproveClick() {
    approving = true;
    approve().finally(() => {
      approving = false;
    });
  }

  function onBridgeClick() {
    bridging = true;
    bridge();
  }

  //TODO: this should probably be checked somewhere else?
  export async function checkTokensApproved() {
    $validatingAmount = true;
    if ($selectedToken?.type === TokenType.ERC721 || $selectedToken?.type === TokenType.ERC1155) {
      if ($account?.address && $network?.id && $destNetwork?.id) {
        const currentChainId = $network?.id;
        const destinationChainId = $destNetwork?.id;
        const token = $selectedToken as NFT;

        const result = await checkOwnershipOfNFT(token as NFT, $account?.address, currentChainId);

        if (!result.every((item) => item.isOwner === true)) {
          return false;
        }

        const wallet = await getConnectedWallet();

        const spenderAddress = getContractAddressByType({
          srcChainId: currentChainId,
          destChainId: destinationChainId,
          tokenType: token.type,
          contractType: ContractType.VAULT,
        });

        if (!spenderAddress) {
          throw new Error('No spender address found');
        }

        const args: RequireApprovalArgs = {
          tokenAddress: token.addresses[currentChainId],
          owner: wallet.account.address,
          spenderAddress,
          tokenId: BigInt(token.tokenId),
          chainId: currentChainId,
        };

        if (token.type === TokenType.ERC1155) {
          try {
            const bridge = bridges[token.type] as ERC1155Bridge;

            // Let's check if the vault is approved for all ERC1155
            const result = await bridge.isApprovedForAll(args);
            allTokensApproved = result;
          } catch (error) {
            console.error('isApprovedForAll error');
          }
        } else if (token.type === TokenType.ERC721) {
          const bridge = bridges[token.type] as ERC721Bridge;

          // Let's check if the vault is approved for all ERC721
          try {
            const requiresApproval = await bridge.requiresApproval(args);
            allTokensApproved = !requiresApproval;
          } catch (error) {
            console.error('isApprovedForAll error');
          }
        }
      }
    }
    $validatingAmount = false;
  }

  // TODO: feels like we need a state machine here

  // Basic conditions so we can even start the bridging process
  $: hasAddress = $recipientAddress || $account?.address;
  $: hasNetworks = $network?.id && $destNetwork?.id;
  $: hasBalance =
    !$insufficientBalance &&
    !$computingBalance &&
    !$errorComputingBalance &&
    ($tokenBalance
      ? typeof $tokenBalance === 'bigint'
        ? $tokenBalance > BigInt(0) // ERC721/1155
        : 'value' in $tokenBalance
        ? $tokenBalance.value > BigInt(0)
        : false // ERC20
      : false);
  $: canDoNothing = !hasAddress || !hasNetworks || !hasBalance || !$selectedToken;

  // Conditions for approve/bridge steps
  $: isSelectedERC20 = $selectedToken && $selectedToken.type === TokenType.ERC20;

  $: isTokenApproved =
    $selectedToken?.type === TokenType.ERC20
      ? isSelectedERC20 && $enteredAmount && !$insufficientAllowance && !$validatingAmount
      : $selectedToken?.type === TokenType.ERC721
      ? allTokensApproved
      : $selectedToken?.type === TokenType.ERC1155
      ? allTokensApproved
      : false;

  $: {
    checkTokensApproved();
  }

  // Conditions to disable/enable buttons
  $: disableApprove =
    $selectedToken?.type === TokenType.ERC20
      ? canDoNothing || $insufficientBalance || $validatingAmount || approving || isTokenApproved || !$enteredAmount
      : $selectedToken?.type === TokenType.ERC721
      ? allTokensApproved || approving
      : $selectedToken?.type === TokenType.ERC1155
      ? allTokensApproved || approving
      : approving;

  $: isERC20 = $selectedToken?.type === TokenType.ERC20;
  $: isERC721 = $selectedToken?.type === TokenType.ERC721;
  $: isERC1155 = $selectedToken?.type === TokenType.ERC1155;
  $: isETH = $selectedToken?.type === TokenType.ETH;

  $: commonConditions =
    !bridging &&
    hasAddress &&
    hasNetworks &&
    hasBalance &&
    $selectedToken &&
    !$validatingAmount &&
    !$insufficientBalance;

  $: erc20ConditionsSatisfied =
    !canDoNothing && !$insufficientAllowance && commonConditions && $tokenBalance && $enteredAmount;
  $: erc721ConditionsSatisfied = allTokensApproved && commonConditions;
  $: erc1155ConditionsSatisfied = allTokensApproved && $enteredAmount && $enteredAmount > 0 && commonConditions;
  $: ethConditionsSatisfied = commonConditions && $enteredAmount && $enteredAmount > 0;

  $: disableBridge = isERC20
    ? !erc20ConditionsSatisfied
    : isERC721
    ? !erc721ConditionsSatisfied
    : isERC1155
    ? !erc1155ConditionsSatisfied
    : isETH
    ? !ethConditionsSatisfied
    : commonConditions;
</script>

<!-- bridging {bridging}<br />
balance {hasBalance}<br />
validating {$validatingAmount}<br />
insufficientAllowance {$insufficientAllowance}<br /><br />

canDoNothing {canDoNothing} <br />
$insufficientAllowance {insufficientAllowance} <br />
commonConditions {commonConditions}
enteredAmount {$enteredAmount}<br />
tokenBalance {$tokenBalance}<br />
enteredAmount {#if $enteredAmount}test
{/if}<br /> -->

{#if oldStyle}
  <!-- TODO: temporary enable two styles, remove for UI v2.1 -->

  <div class="f-between-center w-full gap-4">
    {#if $selectedToken && $selectedToken.type !== TokenType.ETH}
      <Button
        type="primary"
        class="px-[28px] py-[14px] rounded-full flex-1"
        disabled={disableApprove}
        loading={approving}
        on:click={onApproveClick}>
        {#if approving}
          <span class="body-bold">{$t('bridge.button.approving')}</span>
        {:else if isTokenApproved}
          <div class="f-items-center">
            <Icon type="check" />
            <span class="body-bold">{$t('bridge.button.approved')}</span>
          </div>
        {:else}
          <span class="body-bold">{$t('bridge.button.approve')}</span>
        {/if}
      </Button>
      <Icon type="arrow-right" />
    {/if}
    <Button
      type="primary"
      class="px-[28px] py-[14px] rounded-full flex-1 text-white"
      disabled={disableBridge}
      loading={bridging}
      on:click={onBridgeClick}>
      {#if bridging}
        <span class="body-bold">{$t('bridge.button.bridging')}</span>
      {:else}
        <span class="body-bold">{$t('bridge.button.bridge')}</span>
      {/if}
    </Button>
  </div>
{:else}
  <div class="f-col w-full gap-4">
    {#if $selectedToken && $selectedToken.type !== TokenType.ETH}
      <Button
        type="primary"
        class="px-[28px] py-[14px] rounded-full flex-1"
        disabled={disableApprove}
        loading={approving}
        on:click={onApproveClick}>
        {#if approving}
          <span class="body-bold">{$t('bridge.button.approving')}</span>
        {:else if isTokenApproved}
          <div class="f-items-center">
            <Icon type="check" />
            <span class="body-bold">{$t('bridge.button.approved')}</span>
          </div>
        {:else}
          <span class="body-bold">{$t('bridge.button.approve')}</span>
        {/if}
      </Button>
    {/if}
    <Button
      type="primary"
      class="px-[28px] py-[14px] rounded-full flex-1 text-white"
      disabled={disableBridge}
      loading={bridging}
      on:click={onBridgeClick}>
      {#if bridging}
        <span class="body-bold">{$t('bridge.button.bridging')}</span>
      {:else}
        <span class="body-bold">{$t('bridge.button.bridge')}</span>
      {/if}
    </Button>
  </div>
{/if}
