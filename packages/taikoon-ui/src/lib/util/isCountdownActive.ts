import { PUBLIC_LAUNCH_DATE } from '$env/static/public';

export default function isCountdownActive(): boolean {
  const launchDate = new Date(PUBLIC_LAUNCH_DATE);
  return Date.now() < launchDate.getTime();
}
