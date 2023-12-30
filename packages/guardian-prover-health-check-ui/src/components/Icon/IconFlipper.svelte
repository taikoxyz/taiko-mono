<script lang="ts">
	import { createEventDispatcher } from 'svelte';

	import { Icon, type IconType } from '$components/Icon';
	import { classNames } from '$lib/util/classNames';

	export let iconType1: IconType;
	export let iconType2: IconType;

	export let size: number = 20;

	export let selectedDefault: IconType = iconType1;

	export let flipped: boolean = false;

	export let flipType: 'swap-rotate' | 'swap-flip' | '' = '';

	const dispatch = createEventDispatcher();

	function handleLabelClick() {
		selectedDefault = selectedDefault === iconType1 ? iconType2 : iconType1;
		flipped = !flipped;
		dispatch('labelclick');
	}

	// $: isDefault = selectedDefault === iconType1;
	$: isDefault = !flipped;

	$: classes = classNames('swap  btn-neutral', flipType, $$props.class);
</script>

<div
	role="button"
	tabindex="0"
	class={classes}
	on:click={handleLabelClick}
	on:keypress={handleLabelClick}
>
	<input type="checkbox" class="border-none" bind:checked={isDefault} />
	<Icon type={iconType1} class="fill-primary-icon swap-on" {size} />
	<Icon type={iconType2} class="fill-primary-icon swap-off" {size} />
</div>
