<script lang="ts">
  import { createEventDispatcher } from 'svelte';
  import { fade, scale } from 'svelte/transition';

  import { classNames } from '../../../lib/util/classNames';
  import { IconButton } from '../IconButton';

  const dispatch = createEventDispatcher();
  export let canClose: boolean = true;

  export let open: boolean = false;

  const backdropClasses = classNames(
    'fixed',
    'top-0',
    'left-0',
    'w-full',
    'h-full',
    'glassy-background-md',
    'z-100',
    'flex',
    'items-center',
    'justify-center',
    $$props.class,
  );

  const backdropId: string = `modal-${Date.now()}-backdrop`;

  function onBackdropClick(e: any) {
    if (canClose && e.target.id === backdropId) handleClose;
  }

  function handleClose() {
    open = false;
    dispatch('close');
  }

  $: containerClasses = classNames(
    'md:bg-neutral-background',
    'bg-background-primary',
    'relative',
    'md:rounded-3xl',
    'md:w-full md:h-full',
    'flex flex-col',
    'justify-start',
    'items-center',
    'cursor-default',
    'overflow-hidden',
    'w-screen h-screen',
  );

  const closeButtonClasses = classNames('text-icon-primary', 'absolute', 'right-5', 'top-5');
</script>

{#if open}
  <div
    transition:fade={{ duration: 300 }}
    id={backdropId}
    tabindex={0}
    role="button"
    on:keydown={() => {}}
    aria-label="Close modal"
    class={backdropClasses}
    on:click={onBackdropClick}>
    <div class="">
      <div class={containerClasses} transition:scale={{ duration: 300 }}>
        <slot />

        {#if canClose}
          <IconButton
            type="ghost"
            on:click={() => {
              handleClose();
            }}
            size="sm"
            class={closeButtonClasses}
            icon="XSolid"
            shape="circle" />
        {/if}
      </div>
    </div>
  </div>
{/if}
