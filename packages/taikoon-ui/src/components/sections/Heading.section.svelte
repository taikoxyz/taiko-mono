<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { t } from 'svelte-i18n';

  import LogoBlack from '$assets/taikoons-big-black.png';
  import LogoWhite from '$assets/taikoons-big-white.png';
  import { AnimatedArrow } from '$components/AnimatedArrow';
  import { classNames } from '$lib/util/classNames';
  import { Theme, theme } from '$stores/theme';
  import { Section } from '$ui/Section';

  $: isDarkTheme = $theme === Theme.DARK;
  $: logo = isDarkTheme ? LogoWhite : LogoBlack;

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const sectionClasses = 'items-center justify-center';
  const imageClasses = classNames('w-full', 'h-auto', 'mb-20');

  const mintNowButtonClasses = classNames(
    'bg-[#C8047D]',
    'font-sans',
    'text-[#F3F3F3]',
    'px-3',
    'py-2',
    'rounded-full',
    'flex flex-row',
    'items-center',
    'justify-center',
    'text-base',
    'font-bold',
    'gap-2.5',
    'hover:bg-[#81899]',
  );

  $: isHovered = false;
</script>

<Section animated={true} width={windowSize === 'sm' ? 'lg' : 'md'} class={sectionClasses}>
  <img src={logo} alt="Taikoons Logo" class={imageClasses} />

  <a
    href="/mint"
    on:mouseenter={() => (isHovered = true)}
    on:mouseleave={() => (isHovered = false)}
    class={mintNowButtonClasses}>
    {$t('buttons.mintNow')}
    <AnimatedArrow {isHovered} />
  </a>

  <slot />
</Section>

<ResponsiveController bind:windowSize />
