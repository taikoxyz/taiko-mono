<script lang="ts">
  import { t } from 'svelte-i18n';

  import LogoBlack from '$assets/taikoons-big-black.png';
  import LogoWhite from '$assets/taikoons-big-white.png';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { classNames } from '$lib/util/classNames';
  import { Theme, theme } from '$stores/theme';
  import { Button } from '$ui/Button';
  import { Section } from '$ui/Section';

  $: isDarkTheme = $theme === Theme.DARK;
  $: logo = isDarkTheme ? LogoWhite : LogoBlack;

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const sectionClasses = 'items-center justify-center';
  const imageClasses = classNames('w-full', 'h-auto', 'mb-20');
</script>

<Section animated={true} width={windowSize === 'sm' ? 'lg' : 'md'} class={sectionClasses}>
  <img src={logo} alt="Taikoons Logo" class={imageClasses} />

  <Button size="xl" wide type="primary" iconRight="ArrowRightFilled">
    <a href="/mint">{$t('buttons.mintNow')}</a>
  </Button>

  <slot />
</Section>

<ResponsiveController bind:windowSize />
