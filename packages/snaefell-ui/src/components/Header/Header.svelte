<script lang="ts">
  import { zeroAddress } from 'viem';

  import TaikoonsIcon from '$assets/taikoons-icon.png';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { MobileMenu } from '$components/MobileMenu';
  import { classNames } from '$lib/util/classNames';
  import { account } from '$stores/account';
  import { pageScroll } from '$stores/pageScroll';

  import type { IAddress } from '../../types';
  import { ConnectButton } from '../ConnectButton';
  import { ThemeButton } from '../ThemeButton';
  import {
    baseHeaderClasses,
    rightSectionClasses,
    taikoonsIconClasses,
    themeButtonSeparatorClasses,
    wrapperClasses,
  } from './classes';
  $: address = zeroAddress as IAddress;

  $: isMobileMenuOpen = false;

  $: headerClasses = classNames(
    baseHeaderClasses,
    $pageScroll ? 'md:glassy-background-lg' : null,
    $pageScroll ? 'md:border-b-[1px] md:border-border-divider-default' : 'md:border-b-[1px] md:border-transparent',
    $$props.class,
  );

  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<MobileMenu isConnected={$account?.isConnected} {address} bind:open={isMobileMenuOpen} />

<div class={wrapperClasses}>
  <div class={classNames(headerClasses, $$props.class)}>
    <a href="/" class={classNames()}>
      <img alt="taikoons-logo" class={taikoonsIconClasses} src={TaikoonsIcon} />
    </a>

    <div class={rightSectionClasses}>
      <ConnectButton connected={$account?.isConnected} />
      <div class="inline-flex">
        <div class={themeButtonSeparatorClasses} />
        <ThemeButton />
      </div>
    </div>
  </div>
</div>

<ResponsiveController bind:windowSize />
