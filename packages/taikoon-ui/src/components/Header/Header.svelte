<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { zeroAddress } from 'viem';

  import TaikoonsIcon from '$assets/taikoons-icon.png';
  import { Icons } from '$components/core/Icons';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { MobileMenu } from '$components/MobileMenu';
  import { classNames } from '$lib/util/classNames';
  import isCountdownActive from '$lib/util/isCountdownActive';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';
  import { pageScroll } from '$stores/pageScroll';
  import { config } from '$wagmi-config';

  import type { IAddress } from '../../types';
  import { ConnectButton } from '../ConnectButton';
  import { ThemeButton } from '../ThemeButton';
  import {
    baseHeaderClasses,
    menuButtonsWrapperClasses,
    mobileMenuButtonClasses,
    navButtonClasses,
    rightSectionClasses,
    taikoonsIconClasses,
    themeButtonSeparatorClasses,
    wrapperClasses,
  } from './classes';
  const { Menu: MenuIcon, XSolid: CloseMenuIcon } = Icons;
  $: address = zeroAddress as IAddress;

  $: isMobileMenuOpen = false;

  $: headerClasses = classNames(
    baseHeaderClasses,
    $pageScroll ? 'md:glassy-background-lg' : null,
    $pageScroll ? 'md:border-b-[1px] md:border-border-divider-default' : 'md:border-b-[1px] md:border-transparent',
    $$props.class,
  );

  $: taikoonsOptions = [
    {
      icon: 'FileImageRegular',
      label: 'The 888',
      href: '/collection/',
    },
  ];

  connectedSourceChain.subscribe(async () => {
    if (address !== zeroAddress) return;
    const account = getAccount(config);
    if (!account.address) return;
    address = account.address;
    taikoonsOptions.push({
      icon: 'FileImageRegular',
      label: 'Collection',
      href: `/collection/${address.toLowerCase()}`,
    });
  });

  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<MobileMenu isConnected={$account?.isConnected} {address} bind:open={isMobileMenuOpen} />

<div class={wrapperClasses}>
  <div class={classNames(headerClasses, $$props.class)}>
    <a href="/" class={classNames()}>
      <img alt="taikoons-logo" class={taikoonsIconClasses} src={TaikoonsIcon} />
    </a>

    {#if windowSize === 'sm'}
      <div class={rightSectionClasses}>
        {#if isCountdownActive()}
          <ThemeButton />
        {:else}
          <button on:click={() => (isMobileMenuOpen = !isMobileMenuOpen)} class={mobileMenuButtonClasses}>
            {#if isMobileMenuOpen}
              <CloseMenuIcon size="14" />
            {:else}
              <MenuIcon size="14" />
            {/if}
          </button>
        {/if}
      </div>
    {:else}
      {#if !isCountdownActive()}
        <div class={menuButtonsWrapperClasses}>
          <a href="/mint" type="neutral" class={navButtonClasses}>Mint</a>

          <a href="/collection" type="neutral" class={navButtonClasses}>Collection</a>
          {#if address !== zeroAddress}
            <a href={`/collection/${address.toLowerCase()}`} type="neutral" class={navButtonClasses}> Your taikoons</a>
          {/if}
        </div>
      {/if}
      <div class={rightSectionClasses}>
        {#if !isCountdownActive()}
          <ConnectButton connected={$account?.isConnected} />
        {/if}
        <div class="hidden md:inline-flex">
          <div class={themeButtonSeparatorClasses} />
          <ThemeButton />
        </div>
      </div>
    {/if}
  </div>
</div>

<ResponsiveController bind:windowSize />
