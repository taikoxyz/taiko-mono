<script lang="ts">
  import { ResponsiveController } from '@taiko/ui-lib';
  import { t } from 'svelte-i18n';

  import { AnimatedEyes } from '$components/AnimatedTaikoon';
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
    'w-[80%]',
    'md:font-normal',
    'md:text-[57px]/[64px]',
    'text-content-primary',
    'font-medium',
    'font-clash-grotesk',
    'text-3xl',
  );
  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  $: eyes = Array.from({ length: windowSize === 'sm' ? 6 : 12 }, (_, i) => i);
</script>

<Section height="fit">
  <div class={classNames('md:py-32', 'mb-32')}>
    <p class={titleClasses}>
      {$t('content.sections.information.title')}
    </p>

    <div class={contentClasses}>
      {$t('content.sections.information.text')}
    </div>

    <div class={classNames('w-full', 'h-min', 'flex', 'absolute', 'left-0', 'mt-12', 'bottom-0')}>
      <!-- eslint-disable-next-line @typescript-eslint/no-unused-vars -->
      {#each eyes as _}
        <div
          class={classNames(
            windowSize === 'sm' ? 'w-1/6' : 'w-1/12',
            'h-max',
            'flex',
            'justify-center',
            'items-center',
          )}>
          <AnimatedEyes />
        </div>
      {/each}
    </div>
  </div>
</Section>
<ResponsiveController bind:windowSize />
