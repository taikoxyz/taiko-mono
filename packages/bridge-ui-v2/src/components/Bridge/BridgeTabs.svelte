<script lang="ts">
  import { t } from 'svelte-i18n';

  import { Button } from '$components/Button';
  import { PUBLIC_NFT_BRIDGE_ENABLED } from '$env/static/public';
  import { classNames } from '$libs/util/classNames';

  import { activeBridge } from './state';
  import { BridgeTypes } from './types';

  let classes = classNames('space-x-2', $$props.class);

  $: isERC20Bridge = $activeBridge === BridgeTypes.FUNGIBLE;
  $: isNFTBridge = $activeBridge === BridgeTypes.NFT;

  const onBridgeClick = (type: BridgeTypes) => {
    activeBridge.set(type);
  };
</script>

{#if PUBLIC_NFT_BRIDGE_ENABLED === 'true'}
  <div class={classes}>
    <Button
      type={isERC20Bridge ? 'primary' : 'neutral'}
      class="px-[28px] py-[14px] rounded-full flex-1 text-white"
      on:click={() => onBridgeClick(BridgeTypes.FUNGIBLE)}>
      <span> {$t('nav.token')}</span>
    </Button>

    <Button
      type={isNFTBridge ? 'primary' : 'neutral'}
      class="px-[28px] py-[14px] rounded-full flex-1 text-white"
      on:click={() => onBridgeClick(BridgeTypes.NFT)}>
      <span> {$t('nav.nft')}</span>
    </Button>
  </div>
{/if}
