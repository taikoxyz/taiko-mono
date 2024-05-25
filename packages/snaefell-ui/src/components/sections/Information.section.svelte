<script lang="ts">
  import { t } from 'svelte-i18n';

  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

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
  );
  const contentClasses = classNames(
    'md:font-normal',
    'md:text-[57px]/[64px]',
    'text-content-primary',
    'font-medium',
    'font-clash-grotesk',
    'text-4xl',
  );

  const contentWrapperClasses = classNames('pt-32', 'w-full', 'h-full');
</script>

<Section height="full">
  <div class={contentWrapperClasses}>
    <p class={titleClasses}>
      {$t('content.sections.information.title')}
    </p>

    <div class={contentClasses}>
      {$t('content.sections.information.text')}
    </div>
  </div>
</Section>
