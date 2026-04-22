<script>
  import { getContext } from 'svelte';
  const ctx = getContext('iconCtx') ?? {};
  let className = ctx.class || '';
  export { className as class };
  export let size = ctx.size || '24';
  export let role = ctx.role || 'img';
  export let color = ctx.color || 'currentColor';
  export let withEvents = ctx.withEvents || false;
  export let ariaLabel = 'youtube logo';
  export let title = {
    id: `youtube-logo-title-${Math.random().toString(36).substring(7)}`,
    title: ariaLabel,
  };
  export let desc = {
    id: `youtube-logo-desc-${Math.random().toString(36).substring(7)}`,
    desc: 'A youtube logo icon',
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
    viewBox="0 0 36 26"
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
      d="M35.0513 6.27637C35.0513 6.27637 34.7095 3.86328 33.6567 2.80371C32.3237 1.40918 30.8335 1.40234 30.1499 1.32031C25.2554 0.964844 17.9067 0.964844 17.9067 0.964844H17.8931C17.8931 0.964844 10.5444 0.964844 5.6499 1.32031C4.96631 1.40234 3.47607 1.40918 2.14307 2.80371C1.09033 3.86328 0.755371 6.27637 0.755371 6.27637C0.755371 6.27637 0.399902 9.11328 0.399902 11.9434V14.5957C0.399902 17.4258 0.748535 20.2627 0.748535 20.2627C0.748535 20.2627 1.09033 22.6758 2.13623 23.7354C3.46924 25.1299 5.21924 25.082 5.99854 25.2324C8.80127 25.499 17.8999 25.5811 17.8999 25.5811C17.8999 25.5811 25.2554 25.5674 30.1499 25.2188C30.8335 25.1367 32.3237 25.1299 33.6567 23.7354C34.7095 22.6758 35.0513 20.2627 35.0513 20.2627C35.0513 20.2627 35.3999 17.4326 35.3999 14.5957V11.9434C35.3999 9.11328 35.0513 6.27637 35.0513 6.27637ZM14.2837 17.8154V7.97852L23.7378 12.9141L14.2837 17.8154Z"
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
    viewBox="0 0 36 26">
    {#if title.id && title.title}
      <title id={title.id}>{title.title}</title>
    {/if}
    {#if desc.id && desc.desc}
      <desc id={desc.id}>{desc.desc}</desc>
    {/if}
    <path
      d="M35.0513 6.27637C35.0513 6.27637 34.7095 3.86328 33.6567 2.80371C32.3237 1.40918 30.8335 1.40234 30.1499 1.32031C25.2554 0.964844 17.9067 0.964844 17.9067 0.964844H17.8931C17.8931 0.964844 10.5444 0.964844 5.6499 1.32031C4.96631 1.40234 3.47607 1.40918 2.14307 2.80371C1.09033 3.86328 0.755371 6.27637 0.755371 6.27637C0.755371 6.27637 0.399902 9.11328 0.399902 11.9434V14.5957C0.399902 17.4258 0.748535 20.2627 0.748535 20.2627C0.748535 20.2627 1.09033 22.6758 2.13623 23.7354C3.46924 25.1299 5.21924 25.082 5.99854 25.2324C8.80127 25.499 17.8999 25.5811 17.8999 25.5811C17.8999 25.5811 25.2554 25.5674 30.1499 25.2188C30.8335 25.1367 32.3237 25.1299 33.6567 23.7354C34.7095 22.6758 35.0513 20.2627 35.0513 20.2627C35.0513 20.2627 35.3999 17.4326 35.3999 14.5957V11.9434C35.3999 9.11328 35.0513 6.27637 35.0513 6.27637ZM14.2837 17.8154V7.97852L23.7378 12.9141L14.2837 17.8154Z"
      fill={color} />
  </svg>
{/if}
