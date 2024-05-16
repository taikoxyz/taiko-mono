<script lang="ts">
	import { classNames } from "$lib/util/classNames";
    import colors from '$lib/theme/colors'
    type IColor = keyof typeof colors
    export let color: IColor
/*
    const colorMap: Record<IColor, string> = {
        'pink-10': "bg-tko-pink-10",
    'pink-50': "bg-tko-pink-50",
    'pink-200': "bg-tko-pink-200",
    "pink-400": "bg-tko-pink-400",
    "pink-500": "bg-tko-pink-500",

    }*/

    // let's build colorMap dynamically
    const colorMap: Record<IColor, string> = Object.keys(colors).reduce((acc: any, key) => {
        acc[key] = `bg-tko-${key}`
        return acc
    }, {} as Record<IColor, string>)

    console.log(colorMap)

    $: bg = `bg-tko-${color}`
    $: bg, console.log(bg, colors[color])
    $: classes = classNames(
        'w-8',
        'h-8',
        'border',
        'rounded-full',
        //`bg-${color}`

        color ? colorMap[color] : null

       //'bg-tko-pink-500'
    );
</script>

<div class={classes}>
</div>
{color}


<div class="bg-tko-test-content-primary w-64 h-64 border"></div>
