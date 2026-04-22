<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { zeroAddress } from 'viem';

  import { Icons } from '$components/core/Icons';
  import { MobileMenu } from '$components/MobileMenu';
  import Token from '$lib/token';
  import User from '$lib/user';
  import { classNames } from '$lib/util/classNames';
  import { account } from '$stores/account';
  import { pageScroll } from '$stores/pageScroll';

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
    $pageScroll ? 'glassy-background-lg' : null,
    $pageScroll ? 'border-b-[1px] border-border-divider-default' : 'border-b-[1px] border-transparent',
    $$props.class,
  );

  $: $account, checkYourCollection();
  $: displayYourTaikoonsButton = false;
  $: isChecking = false;
  async function checkYourCollection() {
    if (isChecking) return;
    isChecking = true;
    if (!$account || !$account.address || $account.address === zeroAddress) {
      displayYourTaikoonsButton = false;
      isChecking = false;
      return;
    }

    if (displayYourTaikoonsButton) return;

    address = $account.address;

    if (!address || address === zeroAddress) {
      isChecking = false;
      return;
    }

    const canMint = await Token.canMint(address);
    const totalMintCount = await User.totalWhitelistMintCount(address);

    displayYourTaikoonsButton = !canMint && totalMintCount > 0;
    isChecking = false;
  }

  let windowSize: 'sm' | 'md' | 'lg' = 'md';
</script>

<MobileMenu isConnected={$account?.isConnected} {address} bind:open={isMobileMenuOpen} />

<div class={wrapperClasses}>
  <div class={classNames(headerClasses, $$props.class)}>
    <a href="/" class={classNames()}>
      <img alt="taikoons-logo" class={taikoonsIconClasses} src="/taikoons-icon.svg" />
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
        <a href="/mint" type="neutral" class={navButtonClasses}>Mint</a>

        <a href="/collection" type="neutral" class={navButtonClasses}>Collection</a>
        {#if displayYourTaikoonsButton}
          <a href={`/collection/${address.toLowerCase()}`} type="neutral" class={navButtonClasses}> Your taikoons</a>
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
