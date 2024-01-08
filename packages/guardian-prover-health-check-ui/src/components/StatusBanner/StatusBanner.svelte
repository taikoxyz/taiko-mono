<script lang="ts">
	import { Alert } from '$components/Alert';
	import { guardianProvers } from '$lib/dataFetcher';
	import { t } from 'svelte-i18n';
	import { AlertType } from '$components/Alert/types';

	// set to 999 by default to avoid false positives
	const proverCount = parseInt(import.meta.env.VITE_PROVER_COUNT) || 999;
	const requiredCount = parseInt(import.meta.env.VITE_REQUIRED_PROVER_COUNT) || 999;

	$: proverStatuses = $guardianProvers
		?.map((guardianProver) => guardianProver.alive)
		.reduce((acc, curr) => acc + curr, 0);

	$: configuredCorrectly = $guardianProvers && $guardianProvers?.length === proverCount;

	$: healthy = configuredCorrectly && proverStatuses >= requiredCount;
	$: unhealthy = configuredCorrectly && proverStatuses === $guardianProvers?.length - 1;
	$: critical = configuredCorrectly && proverStatuses <= requiredCount;

	$: statusType =
		healthy && configuredCorrectly
			? AlertType.SUCCESS
			: unhealthy
				? AlertType.WARNING
				: critical
					? AlertType.ERROR
					: AlertType.ERROR;

	$: proversOnline = `${proverStatuses}`;
</script>

{#if statusType === AlertType.SUCCESS && $guardianProvers?.length > 0}
	<Alert type={AlertType.SUCCESS} forceColumnFlow>
		<p class="font-bold">{$t('status.operational')}</p>
	</Alert>
{:else if statusType === AlertType.ERROR && $guardianProvers?.length > 0}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">
			{$t('status.critical', { values: { online: proversOnline, required: requiredCount } })}
		</p>
	</Alert>
{:else if statusType === AlertType.WARNING && $guardianProvers?.length > 0}
	<Alert type={AlertType.WARNING} forceColumnFlow>
		<p class="font-bold">
			{$t('status.degraded', {
				values: { online: proversOnline, required: requiredCount, total: proverCount }
			})}
		</p>
	</Alert>
{:else if !configuredCorrectly && $guardianProvers !== null}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">{$t('status.configuration_error')}</p>
	</Alert>
{/if}
