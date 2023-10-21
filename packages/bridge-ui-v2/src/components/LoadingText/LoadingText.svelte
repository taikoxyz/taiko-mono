<script lang="ts">
  import { onMount } from 'svelte';

  import { classNames } from '$libs/util/classNames';

  export let mask = 'Loading';

  let maskElem: HTMLSpanElement;
  let classes = classNames('animate-pulse rounded-md', $$props.class);

  onMount(() => {
    // The idea is to use same background color as text color
    const textColor = globalThis.getComputedStyle(maskElem).getPropertyValue('color');
    maskElem.style.backgroundColor = textColor;
  });
</script>

<span class={classes} bind:this={maskElem}>{mask}</span>
