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

export async function fetchGuardianProverHealthChecksFromApi(
	baseURL: string,
	page: number,
	size: number,
	guardianProverId?: number
): Promise<PageResponse<HealthCheck>> {
	let url;
	if (guardianProverId) {
		url = `${baseURL}/${healthCheckRoute}/${guardianProverId}`;
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
	guardianProverId: number
): Promise<HealthCheck> {
	const url = `${baseURL}/${livenessRoute}/${guardianProverId}`;

	const resp = await axios.get<HealthCheck>(url);

	return resp.data;
}

export async function fetchUptimeFromApi(
	baseURL: string,
	guardianProverId: number
): Promise<number> {
	const url = `${baseURL}/${uptimeRoute}/${guardianProverId}`;

	const resp = await axios.get<UptimeResponse>(url);

	return resp.data.uptime;
}

export async function fetchStartupDataFromApi(baseURL: string, guardianProverId: number) {
	const url = `${baseURL}/${mostRecentStartupRoute}/${guardianProverId}`;

	const resp = await axios.get<StartupResponse>(url);

	return resp.data;
}

export async function fetchNodeInfoFromApi(baseURL: string, guardianProverId: number) {
	const url = `${baseURL}/${nodeInfoRoute}/${guardianProverId}`;

	const resp = await axios.get<NodeInfoResponse>(url);

	return resp.data;
}
