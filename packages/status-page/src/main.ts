import "./app.css";
import App from "./App.svelte";
import {Buffer} from 'buffer';

const app = new App({
    target: document.getElementById("app"),
});

// @ts-ignore
window.Buffer = Buffer;

export default app;
