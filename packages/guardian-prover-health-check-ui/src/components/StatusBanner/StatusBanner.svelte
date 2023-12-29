<script lang="ts">
	import { Alert } from '$components/Alert';
	import { guardianProvers } from '$lib/dataFetcher';
	import { t } from 'svelte-i18n';
	import { AlertType } from '$components/Alert/types';

	$: status =
		$guardianProvers
			.map((guardianProver) => guardianProver.alive)
			.reduce((acc, curr) => acc + curr, 0) >= 5;

	$: statusType = status ? AlertType.SUCCESS : AlertType.ERROR;
</script>

{#if statusType === AlertType.SUCCESS && $guardianProvers.length > 0}
	<Alert type={AlertType.SUCCESS} forceColumnFlow>
		<p class="font-bold">{$t('status.operational')}</p>
	</Alert>
{:else if statusType === AlertType.ERROR && $guardianProvers.length > 0}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">{$t('status.degraded')}</p>
	</Alert>
{/if}
