<script lang="ts">
    import { slide } from 'svelte/transition'

    import { Icons } from '$components/core/Icons'
    import { classNames } from '$lib/util/classNames'
    import { Section } from '$ui/Section'
    import { H1 } from '$ui/Text'
    export let options: {
        visible: boolean
        title: string
        content: string
    }[] = []

    const PlusIcon = Icons.PlusSign
    const XIcon = Icons.XSolid
</script>

<Section height="fit">
    <div
        class={classNames(
            'w-full h-full',
            'flex flex-col',
            //'py-20',
            'items-start',
            'justify-center',
            'gap-10',
            'md:text-[1.75rem]',
            'text-xl'
        )}
    >
        <H1>WTF?</H1>
        <div
            class={classNames(
                'w-full',
                'flex flex-col',
                'items-center',
                'justify-center',
                'overflow-hidden',
                'gap-4'
            )}
        >
            {#each options as option}
                <!-- svelte-ignore a11y-click-events-have-key-events -->
                <!-- svelte-ignore a11y-no-static-element-interactions -->
                <div
                    class={classNames(
                        'w-full',
                        'flex flex-col',
                        'items-center',
                        'justify-between',
                        'rounded-[20px]',
                        'bg-neutral-background',
                        'py-8',
                        'px-12',
                        'border-opacity-50',
                        'transition',
                        'hover:text-primary'
                    )}
                    on:click={() => (option.visible = !option.visible)}
                >
                    <div
                        class={classNames(
                            'flex',
                            'flex-row',
                            'w-full',
                            'justify-between',
                            'items-center',

                            'font-medium',
                            'font-clash-grotesk'
                        )}
                    >
                        {option.title}

                        {#if option.visible}
                            <XIcon size="14" />
                        {:else}
                            <PlusIcon size="14" />
                        {/if}
                    </div>
                    {#if option.visible}
                        <div
                            transition:slide
                            class={classNames(
                                'w-full',
                                'h-full',
                                'pt-8',
                                'text-base',
                                'text-content-secondary',
                                'font-clash-grotesk'
                            )}
                        >
                            {option.content}
                        </div>
                    {/if}
                </div>
            {/each}
        </div>
    </div>
</Section>
