<script lang="ts">
	import { classNames } from '$lib/util/classNames';

	export let active = false;

	$: classes = classNames(
		'btn h-[48px] px-[20px] py-[8px] rounded-full flex-1 w-full',
		active
			? 'btn-primary text-white border-none'
			: ' btn-secondary border-none hover:bg-secondary-interactive-accent bg-transparent text-black',
		$$props.class
	);
</script>

<button class={classes} on:click>
	<slot />
</button>
