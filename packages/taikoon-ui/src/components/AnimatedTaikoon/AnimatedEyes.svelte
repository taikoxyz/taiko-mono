<script lang="ts">
  export let size = 'full';
  export let role = 'img';
  export let ariaLabel = 'animated taikoon';
  export let title = {
    id: `animated-taikoon-title-${Math.random().toString(36).substring(7)}`,
    title: ariaLabel,
  };
  export let desc = {
    id: `animated-taikoon-desc-${Math.random().toString(36).substring(7)}`,
    desc: 'An animated taikoon',
  };
  import { onDestroy, onMount } from 'svelte';

  let ariaDescribedby = `${title.id || ''} ${desc.id || ''}`;
  let hasDescription = false;
  $: if (title.id || desc.id) {
    hasDescription = true;
  } else {
    hasDescription = false;
  }

  $: primaryColor = '#E81899'; // primary
  $: secondaryColor = '#FF6FC8'; // secondary

  const colorPairs = [
    { primary: '#4752ef', secondary: '#fae600' },
    { primary: '#6d74bc', secondary: '#e71001' },
    { primary: '#e501e7', secondary: '#0040fa' },
  ];

  $: colorPairIndex = 0;

  let animationIntervalId: any;
  onMount(() => {
    animationIntervalId = setInterval(
      () => {
        colorPairIndex = (Math.random() * colorPairs.length) | 0;
        primaryColor = colorPairs[colorPairIndex].primary;
        secondaryColor = colorPairs[colorPairIndex].secondary;
      },
      250 * Math.random() + 500,
      //750
    );
  });

  onDestroy(() => {
    animationIntervalId && clearInterval(animationIntervalId);
  });
</script>

<svg
  xmlns="http://www.w3.org/2000/svg"
  {...$$restProps}
  {role}
  width={size}
  height={size}
  stroke="none"
  aria-label={ariaLabel}
  aria-describedby={hasDescription ? ariaDescribedby : undefined}
  viewBox="91 61 149 98">
  {#if title.id && title.title}
    <title id={title.id}>{title.title}</title>
  {/if}
  {#if desc.id && desc.desc}
    <desc id={desc.id}>{desc.desc}</desc>
  {/if}
  <rect stroke="none" x="106.895" y="93.4868" width="50.1963" height="50.1963" fill="white" />
  <rect stroke="none" x="124.464" y="93.4868" width="32.6276" height="32.6276" fill={secondaryColor} />
  <rect stroke="none" x="156" y="92" width="18" height="52" fill="#0B101B" />
  <rect stroke="none" x="173.405" y="93.4868" width="50.1963" height="50.1963" fill="white" />
  <rect stroke="none" x="190.974" y="93.4868" width="32.6276" height="32.6276" fill={secondaryColor} />
  <path
    fill-rule="evenodd"
    clip-rule="evenodd"
    stroke="none"
    d="M223.601 77.173H106.895V93.4868H223.601V77.173ZM140.778 93.4869H157.091V109.801H140.778V93.4869ZM207.288 93.4869H223.601V109.801H207.288V93.4869Z"
    fill="#0B101B" />
  <path
    fill-rule="evenodd"
    clip-rule="evenodd"
    stroke="none"
    d="M223.602 60.8594H239.915V143.683L239.915 159.997H173.405V143.683L223.602 143.683L223.602 77.1732H106.895V143.683H157.091V159.997H90.5812V143.683H90.5813V60.8595H106.895V60.8594H223.602Z"
    fill={primaryColor} />
</svg>
