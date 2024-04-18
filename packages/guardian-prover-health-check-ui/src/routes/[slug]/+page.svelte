<script lang="ts">
	import { t } from 'svelte-i18n';
	import { Icon } from '$components/Icon';
	import { HealthChecksList } from '$components/HealthChecks';
	import type { PageData } from './$types';
	import { refreshData } from '$lib/dataFetcher';
	import { get } from 'svelte/store';
	import { selectedGuardianProver, guardianProvers } from '$stores';
	import type { Guardian } from '$lib/types';

	export let data: PageData;

	let selected: Guardian = null;

	$: if (get(guardianProvers)) {
		selected = $guardianProvers.find(
			(guardianProver) => Number(guardianProver.id) === parseInt(data.slug)
		);
	} else {
		refreshData().then(() => {
			get(guardianProvers).map((prover) => {
				if (Number(prover.id) === parseInt(data.slug)) {
					selected = prover;
					selectedGuardianProver.set(selected);
				}
			});
		});
	}
</script>

<div class="f-row w-full text-md md:text-[1.5rem]">
	<a href="/" class="">
		<span class="text-left font-bold text-tertiary-content">{$t('headings.overview')}</span>
	</a>

	<div class="pl-[10px] pr-[5px] md:hidden">
		<Icon type="chevron-right" size={15} class="mt-[5px]" />
	</div>
	<div class="flex pl-[10px] pr-[5px] hidden md:inline-block items-center">
		<Icon type="chevron-right" size={22} class="mt-[8px]" />
	</div>
	<span class="font-bold">{selected?.name}</span>
</div>

<div class="mt-[12px]">
	<HealthChecksList selectedGuardianProver={selected} />
</div>
