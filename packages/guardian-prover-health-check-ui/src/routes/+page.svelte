<script lang="ts">
	import { ContentWrapper } from '$components/ContentWrapper';
	import Header from '$components/Header/Header.svelte';
	import { Overview } from '$components/Overview';
	import { Page } from '$components/Page';
	import { t } from 'svelte-i18n';
</script>

<svelte:head>
	<title>{$t('page.title')}</title>
</svelte:head>

<!-- <ContentWrapper /> -->

<Overview />
