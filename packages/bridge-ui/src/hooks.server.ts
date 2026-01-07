import type { Handle } from '@sveltejs/kit';

import { env } from '$env/dynamic/private';

// Parse allowed origins from environment variable
// Format: comma-separated list of origins, supports regex patterns
// Example: "https://example.com,https://*.taiko.xyz,https://app\.example\.com"
function getAllowedOrigins(): string[] {
  const originsEnv = env.WIDGET_IFRAME_ALLOWED_ORIGINS;
  if (!originsEnv) return [];
  return originsEnv
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);
}

// Check if an origin matches any of the allowed patterns
function isOriginAllowed(origin: string | null, allowedPatterns: string[]): boolean {
  if (!origin || allowedPatterns.length === 0) return false;

  return allowedPatterns.some((pattern) => {
    try {
      // Treat each pattern as a regex
      const regex = new RegExp(`^${pattern}$`);
      return regex.test(origin);
    } catch {
      // If regex is invalid, do exact match
      return origin === pattern;
    }
  });
}

export const handle: Handle = async ({ event, resolve }) => {
  const response = await resolve(event);

  // Check if widget iframe embedding is enabled via environment variable
  const widgetIframeEnabled = env.WIDGET_IFRAME_ENABLED === 'true';

  // Allow widget route to be embedded in iframes (if enabled and origin is allowed)
  if (event.url.pathname.startsWith('/widget') && widgetIframeEnabled) {
    const allowedOrigins = getAllowedOrigins();
    const requestOrigin = event.request.headers.get('origin');

    if (allowedOrigins.length === 0) {
      // No origins specified - allow all (backwards compatible)
      response.headers.set('Content-Security-Policy', 'frame-ancestors *');
      response.headers.delete('X-Frame-Options');
    } else if (isOriginAllowed(requestOrigin, allowedOrigins)) {
      // Origin matches allowed pattern
      response.headers.set('Content-Security-Policy', `frame-ancestors ${requestOrigin}`);
      response.headers.delete('X-Frame-Options');
    } else {
      // Origin not allowed - block embedding
      response.headers.set('Content-Security-Policy', "frame-ancestors 'none'");
      response.headers.set('X-Frame-Options', 'DENY');
    }
  } else {
    // Block all other routes from being embedded
    response.headers.set('Content-Security-Policy', "frame-ancestors 'none'");
    response.headers.set('X-Frame-Options', 'DENY');
  }

  return response;
};
