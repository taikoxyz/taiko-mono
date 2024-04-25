<script lang="ts">
    import { classNames } from '$lib/util/classNames'

    import { CommonTextClasses } from './common'

    let classes: string = null
    export { classes as class }
</script>

<div class={classNames(CommonTextClasses, 'font-medium', 'text-h0', classes)}>
    <slot />
</div>
