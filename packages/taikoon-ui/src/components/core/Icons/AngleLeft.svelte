<script>
  import { getContext } from 'svelte';
  const ctx = getContext('iconCtx') ?? {};
  let className = ctx.class || '';
  export { className as class };
  export let size = ctx.size || '24';
  export let role = ctx.role || 'img';
  export let color = ctx.color || 'currentColor';
  export let withEvents = ctx.withEvents || false;
  export let ariaLabel = 'angle left';
  export let title = {
    id: `angle-left-title-${Math.random().toString(36).substring(7)}`,
    title: ariaLabel,
  };
  export let desc = {
    id: `angle-left-desc-${Math.random().toString(36).substring(7)}`,
    desc: 'An angle left icon',
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
    aria-label={ariaLabel}
    aria-describedby={hasDescription ? ariaDescribedby : undefined}
    viewBox="0 0 24 24"
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
      fill-rule="evenodd"
      clip-rule="evenodd"
      d="M7.71967 12.5303C7.42678 12.2374 7.42678 11.7626 7.71967 11.4697L15.2197 3.96967C15.5126 3.67678 15.9874 3.67678 16.2803 3.96967C16.5732 4.26256 16.5732 4.73744 16.2803 5.03033L9.31066 12L16.2803 18.9697C16.5732 19.2626 16.5732 19.7374 16.2803 20.0303C15.9874 20.3232 15.5126 20.3232 15.2197 20.0303L7.71967 12.5303Z"
      fill={color} />
  </svg>
{:else}
  <svg
    xmlns="http://www.w3.org/2000/svg"
    {...$$restProps}
    {role}
    width={size}
    height={size}
    class={className}
    aria-label={ariaLabel}
    aria-describedby={hasDescription ? ariaDescribedby : undefined}
    viewBox="0 0 24 24">
    {#if title.id && title.title}
      <title id={title.id}>{title.title}</title>
    {/if}
    {#if desc.id && desc.desc}
      <desc id={desc.id}>{desc.desc}</desc>
    {/if}

    <path
      fill-rule="evenodd"
      clip-rule="evenodd"
      d="M7.71967 12.5303C7.42678 12.2374 7.42678 11.7626 7.71967 11.4697L15.2197 3.96967C15.5126 3.67678 15.9874 3.67678 16.2803 3.96967C16.5732 4.26256 16.5732 4.73744 16.2803 5.03033L9.31066 12L16.2803 18.9697C16.5732 19.2626 16.5732 19.7374 16.2803 20.0303C15.9874 20.3232 15.5126 20.3232 15.2197 20.0303L7.71967 12.5303Z"
      fill={color} />
  </svg>
{/if}
