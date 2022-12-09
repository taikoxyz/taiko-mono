import { toast } from "@zerodevx/svelte-toast";
import type { SvelteToastOptions } from "@zerodevx/svelte-toast";

export const errorOpts: SvelteToastOptions = {
  theme: {
    "--toastBackground": "#FF0000",
    "--toastColor": "#e3e3e3",
    "--toastHeight": "50px",
    "--toastContainerTop": "auto",
    "--toastContainerRight": "auto",
    "--toastContainerBottom": "2rem",
    "--toastContainerLeft": "auto",
    "--toastBorderRadius": "0.9rem",
  },
};

export const successOpts: SvelteToastOptions = {
  theme: {
    "--toastBackground": "#008000",
    "--toastColor": "#e3e3e3",
    "--toastHeight": "50px",
    "--toastContainerTop": "auto",
    "--toastContainerRight": "auto",
    "--toastContainerBottom": "2rem",
    "--toastContainerLeft": "auto",
    "--toastBorderRadius": "0.9rem",
  },
};

export const errorToast = (msg: string) => {
  toast.push(msg, errorOpts);
};

export const successToast = (msg: string) => {
  toast.push(msg, successOpts);
};
