<script lang="ts">
  import { classNames } from '../../../lib/util/classNames';
  export let animated: boolean = false;

  const wrapperClasses = classNames(
    'absolute',
    'left-[-5vw]',
    'h-full',
    'w-[110vw]',
    'top-0',
    'overflow-hidden',
    'flex',
    'items-center',
    'justify-center',
    'flex-wrap',
  );
  const cellClasses = classNames(
    'w-[40px]',
    'h-[40px]',
    'border',
    'border-opacity-10',
    'border-t[0.2px]',
    'border-slate-400',
    'bg-opacity-30',
  );

  const primaryCell = classNames(cellClasses, 'bg-primary');

  const secondaryCell = classNames(cellClasses, 'bg-[#FFC6E9]', `duration-[${Math.random() * 5000}ms]`);

  $: outerWidth = 0;
  $: innerWidth = 0;
  $: outerHeight = 0;
  $: innerHeight = 0;

  $: rows = Math.ceil(outerWidth / 40) * 1.1;
  $: cols = Math.ceil(outerHeight / 40) * 6;

  const animationClasses = [
    'animate-cell-pulse-5',
    'animate-cell-pulse-7',
    'animate-cell-pulse-negative-5',
    'animate-cell-pulse-negative-7',
  ];

  function getRandomAnimation() {
    return animationClasses[Math.floor(Math.random() * animationClasses.length)];
  }
</script>

<svelte:window bind:innerWidth bind:outerWidth bind:innerHeight bind:outerHeight />

<div class={wrapperClasses}>
  <!-- eslint-disable-next-line @typescript-eslint/no-unused-vars-->
  {#each Array.from({ length: rows * cols }) as _, i}
    {#if animated}
      {@const rnd = Math.floor(Math.random() * 50)}
      {#if i % 50 === rnd}
        {@const classes = classNames(primaryCell, getRandomAnimation())}
        <div class={classes}></div>
      {:else if i % 40 === rnd}
        {@const classes = classNames(secondaryCell, getRandomAnimation())}

        <div class={classes}></div>
      {:else}
        <div class={cellClasses}></div>
      {/if}
    {:else}
      <div class={cellClasses}></div>
    {/if}
  {/each}
</div>
