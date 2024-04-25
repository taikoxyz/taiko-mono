<script lang="ts">
    import Countdown from 'svelte-countdown'

    import { AnimatedTaikoon } from '$components/AnimatedTaikoon'
    import { ResponsiveController } from '$components/core/ResponsiveController'
    import { classNames } from '$lib/util/classNames'
    import formatDate from '$lib/util/formatDate'
    import { Section } from '$ui/Section'

    import { default as TimerItem } from './TimerItem.svelte'

    const timerContainerClass = classNames(
        'z-0',
        'w-full',
        'md:h-[50vh]',
        'h-max',
        'flex',
        'flex-row',
        'items-center',
        'justify-between',
        'text-xs'
    )

    const taikoonClasses = classNames(
        'flex flex-col items-center justify-center',
        'w-[30vw]',
        'px-12',
        'aspect-original',
        'h-full',
        'overflow-visible'
    )

    const separatorClasses = classNames(
        'w-[1px]',
        'h-[64px]',
        'md:mt-[-50px]',
        'mt-[-35px]',
        'bg-divider-border',
        'opacity-50'
    )

    let windowSize: 'sm' | 'md' | 'lg' = 'md'
</script>

<Section class="justify-center items-center" animated>
    {#if windowSize === 'sm'}
        <div class={classNames('w-2/3', 'my-8')}>
            <AnimatedTaikoon />
        </div>
    {/if}
    <Countdown
        zone="UTC"
        from={formatDate(new Date('2024-05-08T00:00:00'))}
        dateFormat="YYYY-MM-DD H:m:s"
        let:remaining
    >
        <div class={timerContainerClass}>
            <TimerItem count={remaining.days} label={remaining.days === 1 ? 'Day' : 'Days'} />

            <div class={separatorClasses}></div>
            <TimerItem count={remaining.hours} label={remaining.hours === 1 ? 'Hour' : 'Hours'} />

            {#if windowSize === 'sm'}
                <div class={separatorClasses}></div>
            {:else}
                <div class={taikoonClasses}>
                    <AnimatedTaikoon />
                </div>
            {/if}
            <TimerItem
                count={remaining.minutes}
                label={remaining.minutes === 1 ? 'Minute' : 'Minutes'}
            />
            <div class={separatorClasses}></div>

            <TimerItem
                count={remaining.seconds}
                label={remaining.seconds === 1 ? 'Second' : 'Seconds'}
            />
        </div>
    </Countdown>

    <slot />
</Section>

<ResponsiveController bind:windowSize />
