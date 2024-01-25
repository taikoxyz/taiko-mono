<script lang="ts">
	import '../app.css';
	import '../i18n';
	import Header from '$components/Header/Header.svelte';
	import { Page } from '$components/Page';
	import { onMount, onDestroy } from 'svelte';
	import { startFetching, stopFetching } from '$lib/dataFetcher';
	import { loading } from '$stores/stores';

	onMount(() => {
		loading.set(false);
		startFetching();
	});

	onDestroy(() => {
		stopFetching();
	});
</script>

<main>
	<Page>
		<Header />
		<slot />
	</Page>
</main>
