<script lang="ts">
	import { Alert } from '$components/Alert';
	import { t } from 'svelte-i18n';
	import { AlertType } from '$components/Alert/types';
	import { Spinner } from '$components/Spinner';
	import { guardianProvers, minGuardianRequirement, loading, totalGuardianProvers } from '$stores';

	$: proverStatusesAlive = $guardianProvers
		?.map((guardianProver) => guardianProver.alive)
		.reduce((acc, curr) => acc + curr, 0);

	$: configuredCorrectly = $guardianProvers && $totalGuardianProvers !== 0;

	$: healthy = configuredCorrectly && proverStatusesAlive === $totalGuardianProvers;
	$: unhealthy = configuredCorrectly && proverStatusesAlive === $totalGuardianProvers - 1;
	$: critical = configuredCorrectly && proverStatusesAlive <= $minGuardianRequirement;

	$: statusType =
		healthy && configuredCorrectly
			? AlertType.SUCCESS
			: unhealthy
				? AlertType.WARNING
				: critical
					? AlertType.ERROR
					: AlertType.ERROR;

	$: proversOnline = `${proverStatusesAlive}`;
</script>

{#if $loading}
	<Alert type={AlertType.NEUTRAL} forceColumnFlow>
		<div class="flex flex-row items-center gap-2">
			<Spinner />
			{$t('loading')}
		</div>
	</Alert>
{:else if statusType === AlertType.SUCCESS && $totalGuardianProvers > 0}
	<Alert type={AlertType.SUCCESS} forceColumnFlow>
		<p class="font-bold">
			{$t('status.operational', {
				values: {
					online: proversOnline,
					required: $minGuardianRequirement,
					total: $totalGuardianProvers
				}
			})}
		</p>
	</Alert>
{:else if statusType === AlertType.ERROR && $totalGuardianProvers > 0}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">
			{$t('status.critical', {
				values: {
					online: proversOnline,
					required: $minGuardianRequirement,
					total: $totalGuardianProvers
				}
			})}
		</p>
	</Alert>
{:else if statusType === AlertType.WARNING && $totalGuardianProvers > 0}
	<Alert type={AlertType.WARNING} forceColumnFlow>
		<p class="font-bold">
			{$t('status.degraded', {
				values: {
					online: proversOnline,
					required: $minGuardianRequirement,
					total: $totalGuardianProvers
				}
			})}
		</p>
	</Alert>
{:else if !configuredCorrectly && $guardianProvers !== null}
	<Alert type={AlertType.ERROR} forceColumnFlow>
		<p class="font-bold">{$t('status.configuration_error')}</p>
	</Alert>
{/if}
