<script lang="ts">
	import { classNames } from '$lib/util/classNames';
	import colors from '$lib/theme/colors';
	type IColor = keyof typeof colors;
	export let color: IColor;
	const colorMap: Record<IColor, string> = Object.keys(colors).reduce(
		(acc: Record<string, string>, key) => {
			acc[key] = `bg-tko-${key}`;
			return acc;
		},
		{} as Record<IColor, string>
	);

	$: classes = classNames(
		'w-8',
		'h-8',
		'border',
		'rounded-full',
		color ? colorMap[color] : 'bg-transparent'
	);
</script>

<div class={classes}></div>
{color}

<div class="bg-tko-test-content-primary w-64 h-64 border"></div>
