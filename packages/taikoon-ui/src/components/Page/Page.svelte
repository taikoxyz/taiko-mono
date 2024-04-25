<script lang="ts">
    import { classNames } from '../../lib/util/classNames'
    let classes: string = ''
    export { classes as class }
</script>

<div
    class={classNames(
        'w-full',
        'h-full',
        'flex',
        'flex-col',
        'items-center',
        'justify-center',
        classes
    )}
>
    <slot />
</div>
