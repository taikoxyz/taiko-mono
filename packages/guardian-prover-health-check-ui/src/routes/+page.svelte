<script lang="ts">
	import { ContentWrapper } from '$components/ContentWrapper';
	import Header from '$components/Header/Header.svelte';
	import { Page } from '$components/Page';
	import { t } from 'svelte-i18n';
	import { onMount, onDestroy } from 'svelte';
	import { startFetching } from '$lib/dataFetcher';

	let stopFetching: () => void;

	onMount(() => {
		stopFetching = startFetching();
	});

	onDestroy(() => {
		stopFetching();
	});
</script>

<svelte:head>
	<title>{$t('page.title')}</title>
</svelte:head>

<Page>
	<Header />
	<ContentWrapper />
</Page>
