type MobileOS = 'Windows' | 'Android' | 'iOS' | null;

function getMobileOS(): MobileOS {
  const { userAgent } = navigator;

  // Windows Phone must come first because its UA might contain "Android"
  if (/windows phone/i.test(userAgent)) {
    return 'Windows';
  }

  if (/android/i.test(userAgent)) {
    return 'Android';
  }

  if (/ipad|iphone|ipod/i.test(userAgent)) {
    return 'iOS';
  }

  return null; // unknown or simply not a mobile
}

// This includes tablets
export function isMobileDevice() {
  return ['Windows', 'Android', 'iOS'].includes(getMobileOS());
}
