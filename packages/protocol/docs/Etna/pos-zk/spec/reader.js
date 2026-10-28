// Optional controls; the complete text and navigation work without JavaScript.
const details = () => [...document.querySelectorAll("article details")];
const openDetails = () =>
  details().forEach((item) => {
    item.open = true;
  });
document.getElementById("expand").addEventListener("click", openDetails);
document.getElementById("collapse").addEventListener("click", () => {
  details().forEach((item) => {
    item.open = false;
  });
});
document
  .getElementById("print")
  .addEventListener("click", () => window.print());
let beforePrint = [];
window.addEventListener("beforeprint", () => {
  beforePrint = details().map((item) => item.open);
  openDetails();
});
window.addEventListener("afterprint", () => {
  details().forEach((item, index) => {
    item.open = beforePrint[index];
  });
});
window.addEventListener("keydown", (event) => {
  if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "f")
    openDetails();
});
