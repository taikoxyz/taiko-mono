<script lang="ts">
  import { t } from 'svelte-i18n';

  import { page } from '$app/stores';
  import { LinkButton } from '$components/LinkButton';
  import { classNames } from '$libs/util/classNames';

  let classes = classNames('space-x-2', $$props.class);

  $: isERC20Bridge = $page.route.id === '/';
  $: isNFTBridge = $page.route.id === '/nft';
</script>

<div class={classes}>
  <LinkButton class="py-2 px-[20px]" href="/" active={isERC20Bridge}>
    <span> {$t('nav.token')}</span>
  </LinkButton>

  <LinkButton class="py-2 px-[20px]" href="/nft" active={isNFTBridge}>
    <span> {$t('nav.nft')}</span>
  </LinkButton>
</div>
