<script>
  import { getContext } from 'svelte';
  const ctx = getContext('iconCtx') ?? {};
  let className = ctx.class || '';
  export { className as class };
  export let size = ctx.size || '24';
  export let role = ctx.role || 'img';
  export let color = ctx.color || 'currentColor';
  export let withEvents = ctx.withEvents || false;
  export let ariaLabel = 'arrow down';
  export let title = {
    id: `arrow-down-title-${Math.random().toString(36).substring(7)}`,
    title: ariaLabel,
  };
  export let desc = {
    id: `arrow-down-desc-${Math.random().toString(36).substring(7)}`,
    desc: 'An arrow down icon',
  };
  let ariaDescribedby = `${title.id || ''} ${desc.id || ''}`;
  let hasDescription = false;
  $: if (title.id || desc.id) {
    hasDescription = true;
  } else {
    hasDescription = false;
  }
</script>

{#if withEvents}
  <svg
    xmlns="http://www.w3.org/2000/svg"
    {...$$restProps}
    {role}
    width={size}
    height={size}
    class={className}
    fill="none"
    aria-label={ariaLabel}
    aria-describedby={hasDescription ? ariaDescribedby : undefined}
    viewBox="0 0 14 14"
    on:click
    on:keydown
    on:keyup
    on:focus
    on:blur
    on:mouseenter
    on:mouseleave
    on:mouseover
    on:mouseout>
    {#if title.id && title.title}
      <title id={title.id}>{title.title}</title>
    {/if}
    {#if desc.id && desc.desc}
      <desc id={desc.id}>{desc.desc}</desc>
    {/if}
    <path
      d="M10.5392 8.4173L6.99835 11.9581L3.45752 8.4173"
      stroke={color}
      stroke-width="0.875"
      stroke-miterlimit="10"
      stroke-linecap="round"
      stroke-linejoin="round" />
    <path
      d="M7 2.04169V11.8592"
      stroke={color}
      stroke-width="0.875"
      stroke-miterlimit="10"
      stroke-linecap="round"
      stroke-linejoin="round" />
  </svg>
{:else}
  <svg
    xmlns="http://www.w3.org/2000/svg"
    {...$$restProps}
    {role}
    width={size}
    height={size}
    class={className}
    fill="none"
    aria-label={ariaLabel}
    aria-describedby={hasDescription ? ariaDescribedby : undefined}
    viewBox="0 0 14 14">
    {#if title.id && title.title}
      <title id={title.id}>{title.title}</title>
    {/if}
    {#if desc.id && desc.desc}
      <desc id={desc.id}>{desc.desc}</desc>
    {/if}
    <path
      d="M10.5392 8.4173L6.99835 11.9581L3.45752 8.4173"
      stroke={color}
      stroke-width="0.875"
      stroke-miterlimit="10"
      stroke-linecap="round"
      stroke-linejoin="round" />
    <path
      d="M7 2.04169V11.8592"
      stroke={color}
      stroke-width="0.875"
      stroke-miterlimit="10"
      stroke-linecap="round"
      stroke-linejoin="round" />
  </svg>
{/if}
