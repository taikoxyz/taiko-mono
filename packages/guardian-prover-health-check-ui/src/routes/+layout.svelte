<script lang="ts">
	import '../app.css';
	import '../i18n';
	import Header from '$components/Header/Header.svelte';
	import { Page } from '$components/Page';
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

<main>
	<Page>
		<Header />
		<slot />
	</Page>
</main>
