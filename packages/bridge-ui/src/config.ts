import type { SvelteToastOptions } from "@zerodevx/svelte-toast";
import wrap from "svelte-spa-router/wrap";
import Home from "./pages/home/Home.svelte";

export const routes = {
  "/": wrap({
    component: Home,
    props: {},
    userData: {},
  }),
};

export const toastOptions: SvelteToastOptions = {
  dismissable: false,
  duration: 4000,
  pausable: false,
};
