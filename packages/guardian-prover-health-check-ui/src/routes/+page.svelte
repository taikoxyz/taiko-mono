<script lang="ts">
	import { Overview } from '$components/Overview';
	import { t } from 'svelte-i18n';
</script>

<svelte:head>
	<title>{$t('page.title')}</title>
</svelte:head>

<Overview />
