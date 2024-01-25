<script lang="ts">
	import { IconFlipper } from '$components/Icon';
	import { closeOnEscapeOrOutsideClick } from '$lib/customActions';
	import { GuardianProverStatus } from '$lib/types';
	import { classNames } from '$lib/util/classNames';
	import { t } from 'svelte-i18n';

	export let selectedStatus: GuardianProverStatus | null = null;

	let flipped = false;

	let iconFlipperComponent: IconFlipper;

	let menuOpen = false;

	const options = [
		{ value: null, label: $t('filter.guardian_status.all') },
		{ value: GuardianProverStatus.DEAD, label: $t('filter.guardian_status.dead') },
		{ value: GuardianProverStatus.UNHEALTHY, label: $t('filter.guardian_status.unhealthy') },
		{ value: GuardianProverStatus.ALIVE, label: $t('filter.guardian_status.alive') }
	];

	const selectOption = (option: (typeof options)[0]) => {
		selectedStatus = option.value;
		menuOpen = false;
	};

	const toggleMenu = () => {
		menuOpen = !menuOpen;
		flipped = !flipped;
	};

	$: menuClasses = classNames(
		'menu absolute right-0 w-[210px] p-3 mt-2 rounded-[10px] bg-neutral-background z-10  box-shadow-small',
		menuOpen ? 'visible opacity-100' : 'invisible opacity-0'
	);
</script>

<div class="relative">
	<button
		aria-haspopup="listbox"
		aria-expanded={menuOpen}
		class="f-between-center w-[210px] min-h-[36px] max-h-[36px] px-6 bg-neutral border-0 shadow-none outline-none rounded-[6px]"
		on:click|stopPropagation={toggleMenu}
	>
		<span class="text-primary-content font-bold">
			{selectedStatus !== null
				? options.find((option) => option.value === selectedStatus)?.label
				: $t('filter.guardian_status.all')}
		</span>
		<IconFlipper
			bind:flipped
			bind:this={iconFlipperComponent}
			iconType1="chevron-left"
			iconType2="chevron-down"
			selectedDefault="chevron-left"
			size={15}
		/>
	</button>

	{#if menuOpen}
		<ul
			role="listbox"
			class={menuClasses}
			use:closeOnEscapeOrOutsideClick={{ enabled: menuOpen, callback: () => (menuOpen = false) }}
		>
			{#each options as option (option.value)}
				<li
					role="option"
					aria-selected={option.value === selectedStatus}
					tabindex="0"
					class="flex items-center h-[56px] px-3 cursor-pointer rounded-[6px]"
					on:click={() => selectOption(option)}
					on:keydown={() => selectOption(option)}
				>
					<span class="flex w-full h-[56px] text-primary-content font-bold">{option.label}</span>
				</li>
			{/each}
		</ul>
	{/if}
</div>
