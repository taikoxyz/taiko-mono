<script lang="ts">
  import { getAccount } from '@wagmi/core';
  import { zeroAddress } from 'viem';

  import TaikoonsIcon from '$assets/taikoons-icon.png';
  import { Icons } from '$components/core/Icons';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { MobileMenu } from '$components/MobileMenu';
  import { classNames } from '$lib/util/classNames';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';
  import { Button } from '$ui/Button';
  import { config } from '$wagmi-config';

  import { ConnectButton } from '../ConnectButton';
  import { ThemeButton } from '../ThemeButton';
  import {
    buttonClasses,
    headerClasses,
    menuButtonsWrapperClasses,
    mobileMenuButtonClasses,
    rightSectionClasses,
    taikoonsIconClasses,
    themeButtonSeparatorClasses,
    wrapperClasses,
  } from './classes';
  const { Menu: MenuIcon, XSolid: CloseMenuIcon } = Icons;
  $: address = zeroAddress;

  $: isMobileMenuOpen = false;

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
        <button on:click={() => (isMobileMenuOpen = !isMobileMenuOpen)} class={mobileMenuButtonClasses}>
          {#if isMobileMenuOpen}
            <CloseMenuIcon size="14" />
          {:else}
            <MenuIcon size="14" />
          {/if}
        </button>
      </div>
    {:else}
      <div class={menuButtonsWrapperClasses}>
        <Button href="/mint" type="neutral" class={buttonClasses}>Mint</Button>

        <Button href="/collection" type="neutral" class={buttonClasses}>Collection</Button>
        {#if address !== zeroAddress}
          <Button href={`/collection/${address.toLowerCase()}`} type="neutral" class={buttonClasses}>
            Your taikoons</Button>
        {/if}
      </div>
      <div class={rightSectionClasses}>
        <ConnectButton connected={$account?.isConnected} />
        <div class="hidden md:inline-flex">
          <div class={themeButtonSeparatorClasses} />
          <ThemeButton />
        </div>
      </div>
    {/if}
  </div>
</div>

<ResponsiveController bind:windowSize />
