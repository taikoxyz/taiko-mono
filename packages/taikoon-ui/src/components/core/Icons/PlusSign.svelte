<script>
  import { getContext } from 'svelte';
  const ctx = getContext('iconCtx') ?? {};
  let className = ctx.class || '';
  export { className as class };
  export let size = ctx.size || '24';
  export let role = ctx.role || 'img';
  export let color = ctx.color || 'currentColor';
  export let withEvents = ctx.withEvents || false;
  export let ariaLabel = 'plus sign';
  export let title = {
    id: `plus-sign-title-${Math.random().toString(36).substring(7)}`,
    title: ariaLabel,
  };
  export let desc = {
    id: `plus-sign-desc-${Math.random().toString(36).substring(7)}`,
    desc: 'A plus sign icon',
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
    viewBox="0 0 17 16"
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
      d="M8.08386 0C8.48474 0 8.80971 0.324975 8.80971 0.725852V7.25852H15.3424C15.7433 7.25852 16.0682 7.5835 16.0682 7.98437C16.0682 8.38525 15.7433 8.71023 15.3424 8.71023H8.80971V15.2429C8.80971 15.6438 8.48474 15.9688 8.08386 15.9688C7.68298 15.9688 7.35801 15.6438 7.35801 15.2429V8.71023H0.825339C0.424462 8.71023 0.0994873 8.38525 0.0994873 7.98437C0.0994873 7.5835 0.424462 7.25852 0.825339 7.25852H7.35801V0.725852C7.35801 0.324975 7.68298 0 8.08386 0Z"
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
    viewBox="0 0 17 16">
    {#if title.id && title.title}
      <title id={title.id}>{title.title}</title>
    {/if}
    {#if desc.id && desc.desc}
      <desc id={desc.id}>{desc.desc}</desc>
    {/if}

    <path
      fill-rule="evenodd"
      clip-rule="evenodd"
      d="M8.08386 0C8.48474 0 8.80971 0.324975 8.80971 0.725852V7.25852H15.3424C15.7433 7.25852 16.0682 7.5835 16.0682 7.98437C16.0682 8.38525 15.7433 8.71023 15.3424 8.71023H8.80971V15.2429C8.80971 15.6438 8.48474 15.9688 8.08386 15.9688C7.68298 15.9688 7.35801 15.6438 7.35801 15.2429V8.71023H0.825339C0.424462 8.71023 0.0994873 8.38525 0.0994873 7.98437C0.0994873 7.5835 0.424462 7.25852 0.825339 7.25852H7.35801V0.725852C7.35801 0.324975 7.68298 0 8.08386 0Z"
      fill={color} />
  </svg>
{/if}
