<script lang="ts">
	import { Alert } from '$components/Alert';
	import { guardianProvers } from '$lib/dataFetcher';
	import { t } from 'svelte-i18n';
	import { AlertType } from '$components/Alert/types';
	import { fetchGuardianProverRequirementsFromContract } from '$lib/guardianProver/fetchGuardianProverRequirementsFromContract';
	import { onMount } from 'svelte';
	import { Spinner } from '$components/Spinner';

	// set to 999 by default to avoid false positives
	let requiredCount = 999;

	$: proverStatusesAlive = $guardianProvers
		?.map((guardianProver) => guardianProver.alive)
		.reduce((acc, curr) => acc + curr, 0);

	$: configuredCorrectly = $guardianProvers && $guardianProvers?.length !== 0;

	$: healthy = configuredCorrectly && proverStatusesAlive === $guardianProvers?.length;
	$: unhealthy = configuredCorrectly && proverStatusesAlive === $guardianProvers?.length - 1;
	$: critical = configuredCorrectly && proverStatusesAlive <= requiredCount;

	$: statusType =
		healthy && configuredCorrectly
			? AlertType.SUCCESS
			: unhealthy
				? AlertType.WARNING
				: critical
					? AlertType.ERROR
					: AlertType.ERROR;

	$: proversOnline = `${proverStatusesAlive}`;

	onMount(async () => {
		requiredCount = await fetchGuardianProverRequirementsFromContract();
	});
</script>

{#if statusType === AlertType.SUCCESS && $guardianProvers?.length > 0}
	<Alert type={AlertType.SUCCESS} forceColumnFlow>
		<p class="font-bold">
			{$t('status.operational', {
				values: { online: proversOnline, required: requiredCount, total: $guardianProvers?.length }
			})}
		</p>
	</Alert>
{:else if statusType === AlertType.ERROR && $guardianProvers?.length > 0}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">
			{$t('status.critical', {
				values: { online: proversOnline, required: requiredCount, total: $guardianProvers?.length }
			})}
		</p>
	</Alert>
{:else if statusType === AlertType.WARNING && $guardianProvers?.length > 0}
	<Alert type={AlertType.WARNING} forceColumnFlow>
		<p class="font-bold">
			{$t('status.degraded', {
				values: { online: proversOnline, required: requiredCount, total: $guardianProvers?.length }
			})}
		</p>
	</Alert>
{:else if !configuredCorrectly && $guardianProvers !== null}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">{$t('status.configuration_error')}</p>
	</Alert>
{:else}
	<Spinner /> {$t('loading')}
{/if}
