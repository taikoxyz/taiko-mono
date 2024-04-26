<script lang="ts">
  import { getAccount } from '@wagmi/core';

  import TaikoonsIcon from '$assets/taikoons-icon.png';
  import { Icons } from '$components/core/Icons';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { MobileMenu } from '$components/MobileMenu';
  import { classNames } from '$lib/util/classNames';
  import { ZeroXAddress } from '$lib/util/ZeroXAddress';
  import { account } from '$stores/account';
  import { connectedSourceChain } from '$stores/network';
  import { pageScroll } from '$stores/pageScroll';
  import { Button } from '$ui/Button';
  import { config } from '$wagmi-config';

  import { ConnectButton } from '../ConnectButton';
  import { ThemeButton } from '../ThemeButton';
  const { Menu: MenuIcon, XSolid: CloseMenuIcon } = Icons;
  $: address = ZeroXAddress;
  const wrapperClasses = classNames('w-full', 'z-0', 'fixed', 'top-0');

  $: isMobileMenuOpen = false;

  $: headerClasses = classNames(
    'md:px-10',
    'md:py-10',
    'h-16',
    'flex flex-row',
    'justify-between',
    'items-center',
    'gap-4',
    'relative',
    'z-50',
    'px-4',
    $pageScroll ? 'md:glassy-background-lg' : null,
    $pageScroll ? 'md:border-b-[1px] md:border-border-divider-default' : 'md:border-b-[1px] md:border-transparent',
    $$props.class,
  );

  const buttonClasses = classNames('text-lg', 'w-min', 'lg:w-[200px]');

  const taikoonsIconClasses = classNames('h-full');

  const rightSectionClasses = classNames(
    'md:right-8',
    'right-4',
    'w-max',
    'flex flex-row justify-center items-center',
    'gap-4',
  );

  $: taikoonsOptions = [
    {
      icon: 'FileImageRegular',
      label: 'The 888',
      href: '/collection/',
    },
  ];

  connectedSourceChain.subscribe(async () => {
    if (address !== ZeroXAddress) return;
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
  <div class={headerClasses}>
    <a href="/" class={classNames()}>
      <img alt="taikoons-logo" class={taikoonsIconClasses} src={TaikoonsIcon} />
    </a>

    {$pageScroll}

    {#if windowSize === 'sm'}
      <div class={rightSectionClasses}>
        <button
          on:click={() => (isMobileMenuOpen = !isMobileMenuOpen)}
          class={classNames(
            'bg-interactive-tertiary',
            'rounded-full',
            'w-[50px]',
            'h-[50px]',
            'flex justify-center items-center',
          )}>
          {#if isMobileMenuOpen}
            <CloseMenuIcon size="14" />
          {:else}
            <MenuIcon size="14" />
          {/if}
        </button>
      </div>
    {:else}
      <div class={classNames('w-max', 'gap-4', 'flex', 'flex-row')}>
        <Button href="/mint" type="neutral" class={buttonClasses}>Mint</Button>

        <Button href="/collection" type="neutral" class={buttonClasses}>Collection</Button>
        {#if address !== ZeroXAddress}
          <Button href={`/collection/${address.toLowerCase()}`} type="neutral" class={buttonClasses}>
            Your taikoons</Button>
        {/if}
      </div>
      <div class={rightSectionClasses}>
        <ConnectButton connected={$account?.isConnected} />
        <div class="hidden md:inline-flex">
          <div class="v-sep my-auto ml-0 mr-4 h-[24px]" />
          <ThemeButton />
        </div>
      </div>
    {/if}
  </div>
</div>

<ResponsiveController bind:windowSize />
