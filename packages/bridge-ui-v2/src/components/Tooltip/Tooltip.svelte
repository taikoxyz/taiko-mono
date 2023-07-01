<script lang="ts">
  import { onDestroy, onMount } from 'svelte';

  import { Icon } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';
  import { positionElementByTarget } from '$libs/util/positionElementByTarget';
  import { uid } from '$libs/util/uid';

  export let position: Position = 'top';

  let tooltipId = `tooltip-${uid()}`;
  let tooltipOpen = false;
  let classes = classNames('flex', $$props.class || 'relative');

  const GAP = 10; // distance between trigger element and tooltip
  let triggerElem: HTMLButtonElement;
  let dialogElem: HTMLDialogElement;

  function closeTooltip() {
    tooltipOpen = false;
  }

  function openTooltip(event: Event) {
    event.stopPropagation();
    tooltipOpen = true;
  }

  onMount(() => {
    positionElementByTarget(dialogElem, triggerElem, position, GAP);
    document.addEventListener('click', closeTooltip);
  });

  onDestroy(() => {
    closeTooltip();
    document.removeEventListener('click', closeTooltip);
  });
</script>

<div class={classes}>
  <button
    aria-haspopup="dialog"
    aria-controls={tooltipId}
    aria-expanded={tooltipOpen}
    on:click={openTooltip}
    on:focus={openTooltip}
    bind:this={triggerElem}>
    <Icon type="question-circle" />
  </button>

  <dialog id={tooltipId} class="block rounded-[10px]" class:block-hidden={!tooltipOpen} bind:this={dialogElem}>
    <slot />
  </dialog>
</div>
