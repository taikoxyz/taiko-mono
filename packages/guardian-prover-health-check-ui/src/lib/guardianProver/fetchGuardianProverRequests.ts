import { healthCheckRoute } from "$lib/routes";
import type { HealthCheck, PageResponse } from "$lib/types";
import axios from "axios";

export async function fetchGuardianProverRequests(
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
            size: size,
        },
    });

    return resp.data;
}