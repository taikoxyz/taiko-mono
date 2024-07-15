import { addMessages, getLocaleFromNavigator, init } from 'svelte-i18n';

import en from './en.json';
// TODO: import other languages here...

addMessages('en', en);
// TODO: add other languages here...

init({
  fallbackLocale: 'en',
  initialLocale: getLocaleFromNavigator(),
});
