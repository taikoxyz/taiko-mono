<script lang="ts">
  import { Footer, ResponsiveController } from '@taiko/ui-lib';
  import { t } from 'svelte-i18n';

  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  const infoSectionClasses = classNames('justify-center items-center', 'mb-5', 'pt-32');
  const footerSectionClasses = classNames('justify-end', 'w-full', 'mb-5', 'pt-32');

  const titleClasses = classNames(
    'w-full',
    'text-left',
    'text-primary',
    'mb-6',
    'uppercase',
    'tracking-normal',
    'text-[16px]/[24px]',
    'font-bold',
    'font-sans',
    'leading-relaxed',
  );

  const contentClasses = classNames(
    'md:font-normal',
    'md:text-[45px]/[52px]',
    'text-[32px]/[40px]',
    'my-4',
    'md:my-6',
    'text-content-primary',
    'font-medium',
    'font-clash-grotesk',
  );

  const contentWrapperClasses = classNames('w-full', 'h-full', 'max-w-[1000px]', 'lg:px-2', 'md:px-6', 'px-4');
</script>

<Section height={'fit'} class={infoSectionClasses} width="xl">
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

<Section height={'fit'} class={footerSectionClasses} width="xl">
  <Footer />
</Section>

<ResponsiveController bind:windowSize />
