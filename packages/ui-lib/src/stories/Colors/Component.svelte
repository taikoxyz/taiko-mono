<script lang="ts">
	import { classNames } from "$lib/util/classNames";
    import colors from '$lib/theme/colors'
    export let color: keyof typeof colors = "tko-pink-10"

    $: bg = `bg-${color}`
    $: bg, console.log(bg, colors[color])
    $: classes = classNames(
        'w-8',
        'h-8',
        'border',
        'rounded-full',
        //`bg-${color}`
       bg
       //'bg-tko-pink-500'
    );
</script>

<div class={classes}>
</div>
{color}
