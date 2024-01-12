<script lang="ts">
	import { classNames } from '$lib/util/classNames';

	export let active = false;

	$: classes = classNames(
		'btn md:h-[48px] md:px-[20px] py-[20px] md:py-[8px] rounded-full flex-1 w-full btn-sm content-center',
		active
			? 'btn-primary text-white border-none'
			: ' btn-secondary border-none hover:bg-secondary-interactive-accent bg-transparent text-black',
		$$props.class
	);
</script>

<button class={classes} on:click>
	<slot />
</button>
