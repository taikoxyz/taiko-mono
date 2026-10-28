// Optional reader controls. Every page reads and navigates without JavaScript.
const details = () => [...document.querySelectorAll("[data-source] details")];
const setAll = (open) =>
  details().forEach((item) => {
    item.open = open;
  });

const tools = document.querySelector(".tools");
if (tools) {
  tools.hidden = false;
  tools.addEventListener("click", (event) => {
    const action = event.target.closest("button")?.dataset.action;
    if (action === "expand") setAll(true);
    else if (action === "collapse") setAll(false);
    else if (action === "print") window.print();
  });
}

// Print and browser find see every detail block; printing restores the previous state.
let beforePrint = [];
window.addEventListener("beforeprint", () => {
  beforePrint = details().map((item) => item.open);
  setAll(true);
});
window.addEventListener("afterprint", () => {
  details().forEach((item, index) => {
    item.open = beforePrint[index] ?? item.open;
  });
});
window.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "f")
    setAll(true);
});
