<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import { Icon, type IconType } from '$components/Icon';
  import { classNames } from '$libs/util/classNames';

  export let iconType1: IconType;
  export let iconType2: IconType;

  export let selectedDefault: IconType = iconType1;

  const dispatch = createEventDispatcher();

  function handleLabelClick() {
    selectedDefault = selectedDefault === iconType1 ? iconType2 : iconType1;
    dispatch('labelclick');
  }

  $: isDefault = selectedDefault === iconType1;

  $: classes = classNames('swap swap-rotate', $$props.class);
</script>

<div role="button" tabindex="0" class={classes} on:click={handleLabelClick} on:keypress={handleLabelClick}>
  <input type="checkbox" class="border-none" bind:checked={isDefault} />
  <Icon type={iconType1} class="fill-primary-icon swap-on" width={25} height={25} vHeight={25} vWidth={25} />
  <Icon type={iconType2} class="fill-primary-icon swap-off" width={25} height={25} vHeight={25} vWidth={25} />
</div>
