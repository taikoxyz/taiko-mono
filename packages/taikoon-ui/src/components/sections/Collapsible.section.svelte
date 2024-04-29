<script lang="ts">
  import { slide } from 'svelte/transition';
  import { t } from 'svelte-i18n';

  import { Icons } from '$components/core/Icons';
  import { classNames } from '$lib/util/classNames';
  import { Section } from '$ui/Section';
  import { H1 } from '$ui/Text';
  export let options: {
    visible?: boolean;
    title: string;
    text: string;
  }[] = [];

  $: activeEntryId = 0;

  const PlusIcon = Icons.PlusSign;
  const XIcon = Icons.XSolid;
</script>

<Section height="fit">
  <div
    class={classNames(
      'w-full h-full',
      'flex flex-col',
      //'py-20',
      'items-start',
      'justify-center',
      'gap-10',
      'md:text-[1.75rem]',
      'text-xl',
    )}>
    <H1>
      {$t('content.sections.faq.title')}
    </H1>

    <div class={classNames('w-full', 'flex flex-col', 'items-center', 'justify-center', 'overflow-hidden', 'gap-4')}>
      {#each options as option, i}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div
          on:click={() => (activeEntryId = activeEntryId === i ? -1 : i)}
          class={classNames(
            'w-full',
            'rounded-[20px]',
            'bg-neutral-background',
            'py-4',
            'h-min',
            'px-6',
            'border-opacity-50',
            'hover:text-primary',
            'collapse',
            'collapse-arrow',
          )}>
          <input class="hidden" type="radio" name="faq-radio-group" checked={i === activeEntryId} />
          <div
            class={classNames(
              'flex',
              'flex-row',
              'w-full',
              'justify-between',
              'items-center',

              'font-medium',
              'font-clash-grotesk',
              'collapse-title',
            )}>
            {option.title}
          </div>
          <div class={classNames('text-base', 'text-content-secondary', 'font-clash-grotesk', 'collapse-content')}>
            {option.text}
          </div>
        </div>
      {/each}
    </div>
  </div>
</Section>
