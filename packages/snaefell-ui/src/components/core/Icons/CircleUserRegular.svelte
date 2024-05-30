<script>
  import { getContext } from 'svelte';
  const ctx = getContext('iconCtx') ?? {};
  let className = ctx.class || '';
  export { className as class };
  export let size = ctx.size || '24';
  export let role = ctx.role || 'img';
  export let color = ctx.color || 'currentColor';
  export let withEvents = ctx.withEvents || false;
  export let ariaLabel = 'circle user regular';
  export let title = {
    id: `circle-user-regular-title-${Math.random().toString(36).substring(7)}`,
    title: ariaLabel,
  };
  export let desc = {
    id: `circle-user-regular-desc-${Math.random().toString(36).substring(7)}`,
    desc: 'A circle user regular icon',
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
    fill={color}
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
      d="M18.8139 19.2336C20.737 17.4214 21.9375 14.8509 21.9375 12C21.9375 6.51167 17.4883 2.0625 12 2.0625C6.51167 2.0625 2.0625 6.51167 2.0625 12C2.0625 14.8509 3.263 17.4214 5.18606 19.2336C6.96512 20.9101 9.36257 21.9375 12 21.9375C14.6374 21.9375 17.0349 20.9101 18.8139 19.2336ZM6.03253 17.9241C7.43345 16.1766 9.58606 15.0577 12 15.0577C14.4139 15.0577 16.5665 16.1766 17.9675 17.9241C16.4441 19.4585 14.333 20.4087 12 20.4087C9.66698 20.4087 7.55588 19.4585 6.03253 17.9241ZM15.8221 8.94231C15.8221 11.0532 14.1109 12.7644 12 12.7644C9.8891 12.7644 8.17788 11.0532 8.17788 8.94231C8.17788 6.83141 9.8891 5.12019 12 5.12019C14.1109 5.12019 15.8221 6.83141 15.8221 8.94231Z"
      fill={color} />
  </svg>
{:else}
  <svg
    xmlns="http://www.w3.org/2000/svg"
    {...$$restProps}
    {role}
    width={size}
    height={size}
    fill={color}
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
      d="M18.8139 19.2336C20.737 17.4214 21.9375 14.8509 21.9375 12C21.9375 6.51167 17.4883 2.0625 12 2.0625C6.51167 2.0625 2.0625 6.51167 2.0625 12C2.0625 14.8509 3.263 17.4214 5.18606 19.2336C6.96512 20.9101 9.36257 21.9375 12 21.9375C14.6374 21.9375 17.0349 20.9101 18.8139 19.2336ZM6.03253 17.9241C7.43345 16.1766 9.58606 15.0577 12 15.0577C14.4139 15.0577 16.5665 16.1766 17.9675 17.9241C16.4441 19.4585 14.333 20.4087 12 20.4087C9.66698 20.4087 7.55588 19.4585 6.03253 17.9241ZM15.8221 8.94231C15.8221 11.0532 14.1109 12.7644 12 12.7644C9.8891 12.7644 8.17788 11.0532 8.17788 8.94231C8.17788 6.83141 9.8891 5.12019 12 5.12019C14.1109 5.12019 15.8221 6.83141 15.8221 8.94231Z"
      fill={color} />
  </svg>
{/if}

<!--
@component
[Go to docs](https://svelte-awesome-icons.codewithshin.com)
## Props
@prop export let size: string = ctx.size || '24';
@prop export let role: string = ctx.role || 'img';
@prop export let color: string = ctx.color || 'currentColor';
@prop export let withEvents = ctx.withEvents || false;
@prop export let ariaLabel: string = 'circle user regular';
@prop export let title: TitleType = {};
@prop export let desc: DescType = {};
-->
