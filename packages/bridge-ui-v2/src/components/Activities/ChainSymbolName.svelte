<script lang="ts">
  import { DesktopOrLarger } from '$components/DesktopOrLarger';
  import { chainIcons, type ChainID, getChainName } from '$libs/chain';

  export let chainId: ChainID;
  let isDesktopOrLarger: boolean;
  const chainName = getChainName(Number(chainId));
  const icon = chainIcons[Number(chainId)];
</script>

<div class="flex {isDesktopOrLarger ? 'items-stretch self-center' : 'justify-items-start'}">
  <img src={icon} alt="chain-logo" class="rounded-full w-5 h-5 hidden md:block mr-2" />
  <span class={isDesktopOrLarger ? 'font-bold' : ''}>{chainName}</span>
</div>
<DesktopOrLarger bind:is={isDesktopOrLarger} />
