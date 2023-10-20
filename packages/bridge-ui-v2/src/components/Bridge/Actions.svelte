<script lang="ts">
  import { t } from 'svelte-i18n';

  import { routingContractsMap } from '$bridgeConfig';
  import { Button } from '$components/Button';
  import { Icon } from '$components/Icon';
  import { bridges } from '$libs/bridge';
  import type { ERC721Bridge } from '$libs/bridge/ERC721Bridge';
  import type { ERC1155Bridge } from '$libs/bridge/ERC1155Bridge';
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

  let approving = false;
  let bridging = false;

  let allTokensApproved = false;

  function onApproveClick() {
    approving = true;
    approve().finally(() => {
      approving = false;
    });
  }

  function onBridgeClick() {
    bridging = true;
    bridge().finally(() => {
      bridging = false;
    });
  }

  //TODO: this should probably be checked somewhere else?
  export async function checkTokensApproved() {
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
        const { erc1155VaultAddress, erc721VaultAddress } = routingContractsMap[currentChainId][destinationChainId];

        if (token.type === TokenType.ERC1155) {
          try {
            const bridge = bridges[token.type] as ERC1155Bridge;

            // Let's check if the vault is approved for all ERC1155
            const result = await bridge.isApprovedForAll({
              tokenAddress: token.addresses[currentChainId],
              owner: wallet.account.address,
              spenderAddress: erc1155VaultAddress,
              tokenId: BigInt(token.tokenId),
              chainId: currentChainId,
            });
            allTokensApproved = result;
          } catch (error) {
            console.error('isApprovedForAll error');
          }
        } else if (token.type === TokenType.ERC721) {
          const bridge = bridges[token.type] as ERC721Bridge;

          // Let's check if the vault is approved for all ERC721
          try {
            const requiresApproval = await bridge.requiresApproval({
              tokenAddress: token.addresses[currentChainId],
              owner: wallet.account.address,
              spenderAddress: erc721VaultAddress,
              tokenId: BigInt(token.tokenId),
              chainId: currentChainId,
            });
            allTokensApproved = !requiresApproval;
          } catch (error) {
            console.error('isApprovedForAll error');
          }
        }
      }
    }
  }
  // TODO: feels like we need a state machine here

  // Basic conditions so we can even start the bridging process
  $: hasAddress = $recipientAddress || $account?.address;
  $: hasNetworks = $network?.id && $destNetwork?.id;
  $: hasBalance =
    !$computingBalance &&
    !$errorComputingBalance &&
    ($tokenBalance
      ? typeof $tokenBalance === 'bigint'
        ? $tokenBalance > BigInt(0) // ERC721/1155
        : 'value' in $tokenBalance
        ? $tokenBalance.value > BigInt(0)
        : false // ERC20
      : false);
  $: canDoNothing = !hasAddress || !hasNetworks || !hasBalance || !$selectedToken || !$enteredAmount;

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
      ? canDoNothing || $insufficientBalance || $validatingAmount || approving || isTokenApproved
      : $selectedToken?.type === TokenType.ERC721
      ? allTokensApproved || approving
      : $selectedToken?.type === TokenType.ERC1155
      ? allTokensApproved || approving
      : approving;

  $: disableBridge =
    $selectedToken?.type === TokenType.ERC20
      ? canDoNothing || $insufficientAllowance || $insufficientBalance || $validatingAmount || bridging
      : $selectedToken?.type === TokenType.ERC721
      ? !allTokensApproved
      : $selectedToken?.type === TokenType.ERC1155
      ? !allTokensApproved
      : bridging || !hasAddress || !hasNetworks || !hasBalance || !$selectedToken || !$enteredAmount;
</script>

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
