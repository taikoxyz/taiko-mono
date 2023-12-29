import { livenessRoute } from "$lib/routes";
import type { HealthCheck } from "$lib/types";
import axios from "axios";

export async function fetchLatestGuardianProverRequest(
    baseURL: string,
    guardianProverId: number
): Promise<HealthCheck> {
    const url = `${baseURL}/${livenessRoute}/${guardianProverId}`;

    const resp = await axios.get<HealthCheck>(url);

    return resp.data;
}
