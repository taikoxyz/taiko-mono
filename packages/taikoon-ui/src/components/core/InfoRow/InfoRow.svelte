<script lang="ts">
    import { classNames } from '../../../lib/util/classNames'
    import { Spinner } from '../Spinner'
    import { Link, P } from '../Text'

    export let label = 'label'
    export let value = 'value'
    export let href = '#'
    export let loading = false

    let classes = ''
    export { classes as class }
</script>

<div class={classNames('flex', 'flex-row', 'items-center', 'justify-between', 'w-full', classes)}>
    <P class="font-bold">{label}</P>
    <Link {href} class="font-bold no-underline">
        {#if loading}
            <Spinner size="xs" />
        {:else}
            {value}
        {/if}
    </Link>
</div>
