<script lang="ts">
    import { classNames } from '$lib/util/classNames'

    let classes = ''
    export { classes as class }
</script>

<div
    class={classNames(
        'px-4',
        'w-full',
        'h-full',

        'flex',
        'flex-col',
        classes
    )}
>
    <slot />
</div>
