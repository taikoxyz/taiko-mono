# This is the dpkg pseudo-vendor profile.
Profile: dpkg/main
# It has all the checks and settings from the "debian" profile.
Extends: debian/main
# Except the ones that are bogus for the non-Debian distributions.
Disable-Tags:
 package-uses-vendor-specific-patch-series
