<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { LinkButton } from '$components/LinkButton';
  $: isERC20Bridge = $page.route.id === '/' ? true : false;
  $: isNFTBridge = $page.route.id === '/nft' ? true : false;
  $: classes = `flex-basis-0 mr-2 p-3 rounded-full flex justify-center items-center  w-auto sm:w-20 2xl:w-32`;
</script>

<div class="flex w-full ml-2">
  <LinkButton class={classes} href="/" active={isERC20Bridge}>
    <span> {$t('nav.token')}</span>
  </LinkButton>

  <LinkButton class={classes} href="/nft" active={isNFTBridge}>
    <span> {$t('nav.nft')}</span>
  </LinkButton>
</div>
