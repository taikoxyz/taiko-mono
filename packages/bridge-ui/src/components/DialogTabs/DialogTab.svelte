<script lang="ts">
  import { createEventDispatcher } from 'svelte';

  import { classNames } from '$libs/util/classNames';

  const dispatch = createEventDispatcher();

  export let active: boolean;

  function onClick() {
    dispatch('click');
  }
</script>

<button
  role="tab"
  aria-selected={active}
  class:tab-active={active}
  class={classNames('tab !border-color-red', active ? 'tab-active ' : '')}
  on:click={onClick}>
  <slot></slot>
</button>

<style>
  .tab {
    box-sizing: border-box !important;
    padding-bottom: 6px;
  }
  .tab:not(.tab-active) {
    border-color: var(--tertiary-content) !important;
    border-bottom: 1px solid;
    margin-bottom: 2px;
    padding-top: 2px;
  }
  .tab-active {
    border-bottom: 4px solid;
    border-color: var(--primary-brand) !important;
    padding-bottom: 4px;
  }
</style>
