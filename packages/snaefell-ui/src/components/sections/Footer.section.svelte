<script lang="ts">
  import { Footer, ResponsiveController } from '@taiko/ui-lib';
  import { t } from 'svelte-i18n';

  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const sectionClasses = classNames('justify-end align-end', 'mb-5');

  const titleClasses = classNames(
    'w-full',
    'text-left',
    'text-primary',
    'mb-4',
    'uppercase',
    'tracking-normal',
    'text-[16px]/[24px]',
    'font-bold',
    'font-sans',
    'leading-relaxed',
    'px-12',
  );

  const contentClasses = classNames(
    'md:font-normal',
    //'md:text-[57px]/[64px]',
    'md:text-3xl',
    'text-2xl',
    'my-4',
    'md:my-6',
    'text-content-primary',
    'font-medium',
    'font-clash-grotesk',
    'text-4xl',
    // sm variant
    'w-full',
    'px-0',
    // md variant
    'md:w-3/4',
    'md:px-12',
  );

  const contentWrapperClasses = classNames('pt-32', 'w-full', 'h-full');
</script>

<Section height={'max'} class={sectionClasses} width="xl">
  <div class={contentWrapperClasses}>
    <p class={titleClasses}>
      {$t('content.sections.information.title')}
    </p>

    <div class={contentClasses}>
      {$t('content.sections.information.text1')}
    </div>

    <div class={contentClasses}>
      {$t('content.sections.information.text2')}
    </div>

    <div class={contentClasses}>
      {$t('content.sections.information.text3')}
    </div>
  </div>
</Section>
<Section height={'max'} class={sectionClasses} width="xl">
  <Footer />
</Section>

<ResponsiveController bind:windowSize />
