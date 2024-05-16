<script lang="ts">
  import { t } from 'svelte-i18n';

  import { AnimatedTaikoon } from '$components/AnimatedTaikoon';
  import { ResponsiveController } from '$components/core/ResponsiveController';
  import { PUBLIC_LAUNCH_DATE } from '$env/static/public';
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';

  const taikoonClasses = classNames(
    'flex flex-col items-center justify-center',
    'w-[30vw]',
    'px-12',
    'aspect-original',
    'h-full',
    'overflow-visible',
  );

  let windowSize: 'sm' | 'md' | 'lg' = 'md';

  let counters = [
    { label: $t('time.days'), value: 0 },
    { label: $t('time.hours'), value: 0 },
    { label: $t('time.minutes'), value: 0 },
    { label: $t('time.seconds'), value: 0 },
  ];

  const targetDate = new Date(PUBLIC_LAUNCH_DATE);
  setInterval(() => {
    const now = new Date();
    const diff = targetDate.getTime() - now.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((diff % (1000 * 60)) / 1000);

    counters = [
      { label: days === 1 ? $t('time.day') : $t('time.days'), value: days },
      { label: hours === 1 ? $t('time.hour') : $t('time.hours'), value: hours },
      { label: minutes === 1 ? $t('time.minute') : $t('time.minutes'), value: minutes },
      { label: seconds === 1 ? $t('time.second') : $t('time.seconds'), value: seconds },
    ];
  }, 1000);

  const containerClasses = classNames(
    'w-[15vw]',
    'h-full',
    'flex',
    'flex-col',
    'gap-4',
    'items-center',
    'justify-center',
    'z-10',
  );

  const countClasses = classNames(
    'countdown',
    'font-clash-grotesk',
    'text-center',
    'w-full',
    'flex',
    'items-center',
    'justify-center',
    'font-medium',
    'md:text-h0',
    'text-5xl',
  );
  const labelClasses = classNames('text-content-secondary', 'md:text-h4', 'text-center', 'w-full', 'text-sm');
</script>

<Section class="justify-center items-center" animated>
  {#if windowSize === 'sm'}
    <div class={classNames('w-2/3', 'my-8')}>
      <AnimatedTaikoon />
    </div>
  {/if}

  <div class={classNames('w-full', 'flex', 'items-center', 'justify-center')}>
    {#each counters as { label, value }, i}
      {#if i == 2 && windowSize !== 'sm'}
        <div class={taikoonClasses}>
          <AnimatedTaikoon />
        </div>
      {/if}
      <div class={containerClasses}>
        <div class={countClasses}>
          <span style={`--value:${value};`}></span>
        </div>
        <div class={labelClasses}>
          {label}
        </div>
      </div>
    {/each}
  </div>

  <slot />
</Section>

<ResponsiveController bind:windowSize />
