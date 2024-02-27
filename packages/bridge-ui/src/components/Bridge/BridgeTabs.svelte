<script lang="ts">
  import { t } from 'svelte-i18n';

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
    <button
      class="{isERC20Bridge ? 'btn-primary text-white' : 'btn-ghost'} btn h-[40px] px-[28px] rounded-full"
      on:click={() => onBridgeClick(BridgeTypes.FUNGIBLE)}>
      <span> {$t('nav.token')}</span>
    </button>

    <button
      class="{isNFTBridge ? 'btn-primary text-white' : 'btn-ghost'}  btn h-[40px] px-[28px] rounded-full"
      on:click={() => onBridgeClick(BridgeTypes.NFT)}>
      <span> {$t('nav.nft')}</span>
    </button>
  </div>
{/if}
