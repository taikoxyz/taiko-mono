import { addMessages, getLocaleFromNavigator, init } from 'svelte-i18n'

import en from './en.json'

export { _ } from 'svelte-i18n'

addMessages('en', en)

init({
  fallbackLocale: 'en',
  initialLocale: getLocaleFromNavigator(),
})
