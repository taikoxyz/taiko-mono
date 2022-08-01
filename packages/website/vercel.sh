#!/bin/bash

echo "VERCEL_ENV: $VERCEL_ENV"
echo "VERCEL_GIT_COMMIT_REF: $VERCEL_GIT_COMMIT_REF"
echo "VERCEL_GIT_COMMIT_MESSAGE: $VERCEL_GIT_COMMIT_MESSAGE"

if [ "$VERCEL_GIT_COMMIT_REF" == "main" ] ||
   [ "$VERCEL_GIT_COMMIT_REF" == "website-preview" ] ; then
  # [ "$VERCEL_GIT_COMMIT_MESSAGE" == *"(vercel)"* ]; then
  # Proceed with the build
  echo "✅ - Build can proceed"
  exit 1;

else
  # Don't build
  echo "🛑 - Build cancelled"
  exit 0;
fi