<script lang="ts">
  import { t } from 'svelte-i18n';
  import { type Address, parseEther } from 'viem';

  import Alert from '$components/Alert/Alert.svelte';
  import FlatAlert from '$components/Alert/FlatAlert.svelte';
  import { destNetwork, enteredAmount, recipientAddress, selectedNFTs, selectedToken } from '$components/Bridge/state';
  import { claimConfig } from '$config';
  import { recommendProcessingFee } from '$libs/fee';
  import { fetchBalance, type NFT, type Token, TokenType } from '$libs/token';
  import { account, connectedSourceChain } from '$stores';

  import { getManualClaimHref } from './noneOption';

  export let enoughEth: boolean;
  export let calculating = false;
  export let error = false;
  export let selected = false;
  export let headless = false;
  let manualClaimHref: string | null = null;

  /**
   * The inputs change faster than the two reads take: the token, chain, recipient and amount
   * all re-fire this, and a slower earlier run resolving last would answer for inputs that
   * are no longer on screen - re-enabling "None" where a manual claim is not affordable, or
   * bouncing a chosen NONE back to RECOMMENDED on Review. Its sibling RecommendedFee already
   * guards the same shape.
   */
  let computeGeneration = 0;

  async function compute(
    token: Maybe<Token | NFT>,
    userAddress?: Address,
    srcChain?: number,
    destChain?: number,
    to?: Address,
    tokenIds?: number[],
    amounts?: bigint[],
  ) {
    const generation = ++computeGeneration;

    if (!token || !userAddress || !srcChain || !destChain) {
      enoughEth = false;
      return;
    }

    calculating = true;
    error = false;

    try {
      let destBalance;
      // Get the balance of the user on the destination chain
      destBalance = await fetchBalance({
        userAddress,
        srcChainId: destChain,
      });

      // Calculate the recommended amount of ETH needed for processMessage call
      let recommendedAmount = await recommendProcessingFee({
        token,
        destChainId: destChain,
        srcChainId: srcChain,
        to,
        tokenIds,
        amounts,
      });

      const minimumClaimBalance = parseEther(String(claimConfig.minimumEthToClaim));
      if (recommendedAmount <= minimumClaimBalance) {
        // should the fee be very small, set it to at least the minimum
        recommendedAmount = minimumClaimBalance;
      }

      if (generation !== computeGeneration) return;
      // Does the user have enough ETH to claim manually on the destination chain?
      enoughEth = destBalance ? destBalance?.value >= recommendedAmount : false;
    } catch (err) {
      console.error(err);

      if (generation !== computeGeneration) return;
      error = true;
      enoughEth = false;
    } finally {
      // The flag belongs to whichever run is current: clearing it from a superseded one
      // would stop the spinner while the run that replaced it is still reading
      if (generation === computeGeneration) calculating = false;
    }
  }

  $: compute(
    $selectedToken,
    $account?.address,
    $connectedSourceChain?.id,
    $destNetwork?.id,
    $recipientAddress || $account?.address,
    $selectedNFTs?.map((nft) => nft.tokenId),
    $selectedToken?.type === TokenType.ERC1155 ? [$enteredAmount] : undefined,
  );
  $: manualClaimHref = getManualClaimHref({ selected, enoughEth });
</script>

{#if !headless}
  {#if !enoughEth}
    <FlatAlert type="error" message={$t('processing_fee.none.warning')} />
  {:else if selected}
    <div class="my-5 space-y-3">
      <Alert type="warning">
        <span class="body-small">
          {$t('processing_fee.none.alert')}
        </span>
      </Alert>

      {#if manualClaimHref}
        <a href={manualClaimHref} class="link inline-flex body-small-bold">
          {$t('processing_fee.none.claim')}
        </a>
      {/if}
    </div>
  {/if}
{/if}
