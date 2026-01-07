import type { Handle } from '@sveltejs/kit';

export const handle: Handle = async ({ event, resolve }) => {
  const response = await resolve(event);

  // Allow widget route to be embedded in iframes
  if (event.url.pathname.startsWith('/widget')) {
    response.headers.set('Content-Security-Policy', 'frame-ancestors *');
    // ALLOWALL is deprecated but some servers/proxies might ignore deletion
    response.headers.set('X-Frame-Options', 'ALLOWALL');
  } else {
    // Block all other routes from being embedded
    response.headers.set('Content-Security-Policy', "frame-ancestors 'none'");
    response.headers.set('X-Frame-Options', 'DENY');
  }

  return response;
};
