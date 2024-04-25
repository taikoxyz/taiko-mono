<script lang="ts">
    import { classNames } from '$lib/util/classNames'

    import { CommonTextClasses } from './common'

    let classes: string = null
    export { classes as class }
</script>

<div class={classNames(CommonTextClasses, 'text-5xl', 'font-semibold', classes)}>
    <slot />
</div>
