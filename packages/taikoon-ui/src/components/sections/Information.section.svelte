<script lang="ts">
  import { t } from 'svelte-i18n';

  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';
</script>

<Section height="min">
  <p
    class={classNames(
      'w-full',
      'text-left',
      'text-primary',
      'mb-4',
      'uppercase',
      'text-base',
      'font-bold',
      'font-sans',
      'leading-relaxed',
    )}>
    {$t('content.sections.information.title')}
  </p>

  <div class={classNames('md:font-normal', 'font-medium', 'md:text-6xl', 'font-clash-grotesk', 'text-4xl')}>
    {$t('content.sections.information.text')}
  </div>
  <slot />
</Section>
