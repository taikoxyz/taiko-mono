<script lang="ts">
  import { BridgeType } from "../domain/bridge";
  import { bridgeType } from "../store/bridge";
</script>

<div class="tabs">
  <a
    class="tab tab-bordered {$bridgeType === BridgeType.ETH
      ? 'tab-active'
      : ''}"
    on:click={() => bridgeType.set(BridgeType.ETH)}>ETH</a
  >
  <a
    class="tab tab-bordered {$bridgeType === BridgeType.ERC20
      ? 'tab-active'
      : ''}"
    on:click={() => bridgeType.set(BridgeType.ERC20)}>ERC20</a
  >
  <a
    class="tab tab-bordered {$bridgeType === BridgeType.NFT
      ? 'tab-active'
      : ''}"
    on:click={() => bridgeType.set(BridgeType.NFT)}>NFT</a
  >
</div>
