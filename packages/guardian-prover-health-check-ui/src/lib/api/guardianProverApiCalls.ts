import {
	healthCheckRoute,
	livenessRoute,
	mostRecentStartupRoute,
	nodeInfoRoute,
	uptimeRoute
} from '$lib/routes';
import type {
	HealthCheck,
	NodeInfoResponse,
	PageResponse,
	StartupResponse,
	UptimeResponse
} from '$lib/types';
import axios from 'axios';
import type { Address } from 'viem';

export async function fetchGuardianProverHealthChecksFromApi(
	baseURL: string,
	page: number,
	size: number,
	guardianProverAddress?: Address
): Promise<PageResponse<HealthCheck>> {
	let url;
	if (guardianProverAddress) {
		url = `${baseURL}/${healthCheckRoute}/${guardianProverAddress}`;
	} else {
		url = `${baseURL}/${healthCheckRoute}`;
	}

	const resp = await axios.get<PageResponse<HealthCheck>>(url, {
		params: {
			page: page,
			size: size
		}
	});

	return resp.data;
}

export async function fetchLatestGuardianProverHealthCheckFromApi(
	baseURL: string,
	guardianProverAddress: Address
): Promise<HealthCheck> {
	const url = `${baseURL}/${livenessRoute}/${guardianProverAddress}`;

	const resp = await axios.get<HealthCheck>(url);

	return resp.data;
}

export async function fetchUptimeFromApi(
	baseURL: string,
	guardianProverAddress: Address
): Promise<number> {
	const url = `${baseURL}/${uptimeRoute}/${guardianProverAddress}`;

	const resp = await axios.get<UptimeResponse>(url);

	return resp.data.uptime;
}

export async function fetchStartupDataFromApi(baseURL: string, guardianProverAddress: Address) {
	const url = `${baseURL}/${mostRecentStartupRoute}/${guardianProverAddress}`;

	const resp = await axios.get<StartupResponse>(url);

	return resp.data;
}

export async function fetchNodeInfoFromApi(baseURL: string, guardianProverAddress: Address) {
	const url = `${baseURL}/${nodeInfoRoute}/${guardianProverAddress}`;

	const resp = await axios.get<NodeInfoResponse>(url);

	return resp.data;
}
