<script lang="ts">
    /*
    import { Icons } from '$ui/Icons'

    import { classNames } from '../../../lib/util/classNames'
    import type { IconType } from '../../../types'
    import { Spinner } from '../Spinner'
*/
    type ButtonType =
        | 'neutral'
        | 'primary'
        | 'secondary'
        | 'accent'
        | 'info'
        | 'success'
        | 'warning'
        | 'error'
        | 'ghost'
        | 'link'
    type ButtonShape = 'circle' | 'square'

    export let type: Maybe<ButtonType> = null
    export let shape: Maybe<ButtonShape> = null
    export let loading = false
    export let outline = false
    export let block = false
    export let wide = false
    export let label = ''
    export let iconLeft: Maybe<any> = null
    export let iconRight: Maybe<any> = null
    export let size: 'sm' | 'md' | 'lg' | 'xl' = 'md'
    export let hasBorder = false
    export let href: string | undefined = undefined

    let borderClasses: string = ''

    if (hasBorder) {
        borderClasses = 'border-1 border-primary-border'
    } else {
        borderClasses = 'border-0'
    }

    // Remember, with Tailwind's classes you cannot use string interpolation: `btn-${type}`.
    // The whole class name must appear in the code in order for Tailwind compiler to know
    // it must be included during build-time.
    // https://tailwindcss.com/docs/content-configuration#dynamic-class-names
    const typeMap: Record<ButtonType, string> = {
        neutral: 'btn-neutral',
        primary: 'btn-primary',
        secondary: 'btn-secondary',
        accent: 'btn-accent',
        info: 'btn-info',
        success: 'btn-success',
        warning: 'btn-warning',
        error: 'btn-error',
        ghost: 'btn-ghost',
        link: 'btn-link',
    }

    const shapeMap: Record<ButtonShape, string> = {
        circle: 'btn-circle',
        square: 'btn-square',
    }
/*
    $: classes = classNames(
        'flex flex-row items-center justify-center',
        'btn h-auto min-h-fit rounded-full',

        type === 'primary' ? 'body-bold' : 'body-regular',

        type ? typeMap[type] : null,
        shape ? shapeMap[shape] : null,

        outline ? 'btn-outline' : null,
        block ? 'btn-block' : null,
        wide ? 'btn-wide' : null,

        // For loading state we want to see well the content,
        // since we're showing some important information.
        loading ? 'btn-disabled !text-primary-content' : null,

        $$restProps.disabled ? borderClasses : '',

        type === 'link'
            ? 'text-text-dark p0 font-bold'
            : size === 'sm'
              ? 'py-2 px-5'
              : size === 'md'
                ? 'py-3 px-7'
                : size === 'lg'
                  ? 'py-5 px-9 text-xl font-bold'
                  : size === 'xl'
                    ? 'py-2 w-max pl-6 pr-2 text-xl font-bold'
                    : null,

        $$props.class
    )
*/
    // Make sure to disable the button if we're in loading state
    $: if (loading) {
        $$restProps.disabled = true
    }

  //  $: IconLeftComponent = Icons[iconLeft as IconType]
  //  $: IconRightComponent = Icons[iconRight as IconType]

    $: iconSize = size === 'sm' ? 16 : size === 'md' ? 16 : size === 'lg' ? 28 : 42

  //  const iconClasses = classNames('mx-1', size === 'lg' ? 'font-bold' : null)

  const classes="btn"
</script>

{#if href}
    <a {...$$restProps} {href} class={classes}>

        {#if label}
            {label}
        {:else}
            <slot />
        {/if}
    </a>
{:else}
    <button {...$$restProps} class={classes} on:click>

        {#if label}
            {label}
        {:else}
            <slot />
        {/if}
    </button>
{/if}
