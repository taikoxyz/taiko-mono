<script lang="ts">
    import { classNames } from '$lib/util/classNames'

    let classes: string
    export { classes as class }

    export let href = '#'
</script>

<a {href} class={classNames('font-sans', 'underline', 'font-bold', classes)}>
    <slot />
</a>
