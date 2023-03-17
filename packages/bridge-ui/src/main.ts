import './app.css';

import { Buffer } from 'buffer';

import App from './App.svelte';

const app = new App({
  target: document.getElementById('app'),
});

// @ts-ignore
window.Buffer = Buffer;

export default app;
