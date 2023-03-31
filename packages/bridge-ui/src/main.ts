import './app.css';
import App from './App.svelte';
import { Buffer } from 'buffer';
import { setupI18n } from './i18n';

global.Buffer = Buffer;

setupI18n({ withLocale: 'en' });

const app = new App({
  target: document.getElementById('app'),
});

export default app;
