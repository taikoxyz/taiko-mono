<script lang="ts">
    import { classNames } from '$lib/util/classNames'

    let classes: string = null
    export { classes as class }
</script>

<div class={classNames('text-content-secondary', 'text-h4', classes)}>
    <slot />
</div>
