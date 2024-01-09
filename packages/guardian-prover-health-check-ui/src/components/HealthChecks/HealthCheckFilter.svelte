<script lang="ts">
	import { Icon } from '$components/Icon';
	import type { HealthCheck } from '$lib/types';

	export let healthChecks: HealthCheck[];
	export let filteredHealthChecks = [];

	let value = '';

	$: if (value !== '') {
		// return an array of health checks that contain the value in the expected address or actual address or status
		filteredHealthChecks = healthChecks.filter((healthCheck) => {
			return (
				healthCheck.expectedAddress.includes(value) ||
				healthCheck.recoveredAddress.includes(value) ||
				healthCheck.alive.toString().includes(value)
			);
		});
	} else {
		filteredHealthChecks = healthChecks;
	}
</script>

<div class="flex justify-start space-x-4 w-full">
	<div class="relative">
		<div class="relative f-items-center w-full">
			<input
				id="search"
				type="text"
				bind:value
				placeholder="Search address, blocks, status"
				class="input border-1 border-grey-400 placeholder:text-tertiary-content w-full rounded-full h-[36px] pl-[40px]"
			/>
			<Icon type="magnifier" class="absolute left-3" size={15} />
		</div>
	</div>
</div>
