<script lang="ts">
	import { TabButton } from '$components/Button';
	import { classNames } from '$lib/util/classNames';
	import { selectedTab } from '$components/stores/pageTabs';
	import { PageTabs } from '$lib/types';
	import { t } from 'svelte-i18n';

	const selectTab = (tab: PageTabs) => {
		selectedTab.set(tab);
	};

	$: classes = classNames('f-row inline-block', $$props.class);
</script>

<div class={classes}>
	<TabButton
		class="whitespace-nowrap"
		active={$selectedTab === PageTabs.GUARDIAN_PROVER}
		on:click={() => selectTab(PageTabs.GUARDIAN_PROVER)}
	>
		{$t('nav.guardian_prover')}
	</TabButton>

	<TabButton active={$selectedTab === PageTabs.BLOCKS} on:click={() => selectTab(PageTabs.BLOCKS)}>
		{$t('nav.blocks')}
	</TabButton>
</div>
