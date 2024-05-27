<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { Footer } from '@taiko/ui-lib';
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
    'md:text-[57px]/[64px]',
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

{#if windowSize === 'sm'}
  <Section height={'min'} class={sectionClasses} width="xl">
    <div class={contentWrapperClasses}>
      <p class={titleClasses}>
        {$t('content.sections.information.title')}
      </p>

      <div class={contentClasses}>
        {$t('content.sections.information.text')}
      </div>
    </div>
  </Section>
  <Section height={'full'} class={sectionClasses} width="xl">
    <Footer />
  </Section>
{:else}
  <Section height={'full'} background="footer" class={sectionClasses} width="xl">
    <div class={contentWrapperClasses}>
      <p class={titleClasses}>
        {$t('content.sections.information.title')}
      </p>

      <div class={contentClasses}>
        {$t('content.sections.information.text')}
      </div>
    </div>

    <Footer />
  </Section>
{/if}

<ResponsiveController bind:windowSize />
