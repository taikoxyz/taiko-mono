<script lang="ts">
	import { TabButton } from '$components/Button';
	import { classNames } from '$lib/util/classNames';
	import { selectedTab } from '$stores';
	import { PageTabs } from '$lib/types';
	import { t } from 'svelte-i18n';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';

	$: $selectedTab =
		$page.route.id === '/'
			? PageTabs.GUARDIAN_PROVER
			: $page.route.id === '/blocks'
				? PageTabs.BLOCKS
				: PageTabs.GUARDIAN_PROVER;

	$: classes = classNames('f-row inline-block gap-2 md:m-0 m-[-4px]', $$props.class);
</script>

<div class={classes}>
	<TabButton
		class="whitespace-nowrap"
		active={$selectedTab === PageTabs.GUARDIAN_PROVER}
		on:click={() => goto('/')}
	>
		{$t('nav.guardian_prover')}
	</TabButton>

	<TabButton active={$selectedTab === PageTabs.BLOCKS} on:click={() => goto('/blocks')}>
		{$t('nav.blocks')}
	</TabButton>
</div>
