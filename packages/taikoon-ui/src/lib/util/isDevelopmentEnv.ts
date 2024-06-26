import { PUBLIC_TEST_ENV } from '$env/static/public';

export const isDevelopmentEnv = PUBLIC_TEST_ENV === 'development';
