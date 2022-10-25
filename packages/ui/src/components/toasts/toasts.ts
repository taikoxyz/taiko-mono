import { toast } from "@zerodevx/svelte-toast";
import { EVENTS } from "../../domain/eventTracker";
import ToastMessage from "./ToastMessage.svelte";

const toastTheme = {
  "--toastBackground": "#212322",
  "--toastColor": "white",
  "--toastBarBackground": "white",
  "--toastMinHeight": "3rem",
  "--toastBarHeight": "2px",
  "--toastHeight": "3rem",
  "--toastWidth": "400px",
};

const successToast = (m: string, target?: "hero", callback?: () => void) => {
  return pushToast(m, EVENTS.TOAST.SUCCESS, target, callback);
};

const activeFailureMessages = new Set<string>();

const failureToast = (
  m: string,
  target?: "hero",
  callback?: () => void
): number => {
  if (activeFailureMessages.has(m)) {
    return;
  }
  activeFailureMessages.add(m);
  const removeActiveMessage = () => {
    activeFailureMessages.delete(m);
    if (callback) {
      callback();
    }
  };
  return pushToast(m, EVENTS.TOAST.FAILURE, target, removeActiveMessage);
};

/*
 * Create and push a toast
 * Returns the number of toasts on the stack
 */
const pushToast = (
  message: string,
  eventName: string,
  target?: "hero",
  callback?: () => void
): number => {
  return toast.push({
    component: {
      src: ToastMessage,
      props: { message: message },
    },
    ...(target && { target: target }),
    theme: toastTheme,
    onpop: callback,
  });
};

export { successToast, failureToast, pushToast };
