<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';

  import { classNames } from '$lib/util/classNames';
  import { account } from '$stores/account';
  import { pageScroll } from '$stores/pageScroll';
  import { Theme, theme } from '$stores/theme';

  import { ConnectButton } from '../ConnectButton';
  import { ThemeButton } from '../ThemeButton';
  import {
    baseHeaderClasses,
    logoClasses,
    rightSectionClasses,
    themeButtonSeparatorClasses,
    wrapperClasses,
  } from './classes';

  $: isDarkTheme = $theme === Theme.DARK;

  $: headerClasses = classNames(
    baseHeaderClasses,
    $pageScroll ? 'glassy-background-lg' : null,
    $pageScroll ? 'border-b-[1px] border-border-divider-default' : 'border-b-[1px] border-transparent',
    $$props.class,
  );

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  $: logoSrc = isDarkTheme ? '/taiko-h-white.svg' : '/taiko-h-black.svg';
</script>

<div class={wrapperClasses}>
  <div class={classNames(headerClasses, $$props.class)}>
    <a href="/" class={logoClasses}>
      <!-- svelte-ignore a11y-missing-attribute -->
      <img src={logoSrc} />
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
