import { addMessages, getLocaleFromNavigator, init } from 'svelte-i18n';

import en from './en.json';
import zhHK from './zh-hk.json';
// TODO: import other languages here...

addMessages('en', en);
addMessages('zh-HK', zhHK);
// TODO: add other languages here...

init({
  fallbackLocale: 'en',
  initialLocale: getLocaleFromNavigator(),
});
