import './styles/app.css';

import { Buffer } from 'buffer';

import App from './App.svelte';
import { setupI18n } from './i18n';

setupI18n({ withLocale: 'en' });

const app = new App({
  target: document.getElementById('app'),
});

// @ts-ignore
window.Buffer = Buffer;

export default app;
