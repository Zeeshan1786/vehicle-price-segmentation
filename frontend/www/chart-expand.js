document.addEventListener("click", function (event) {
  if (!(event.target instanceof Element)) return;
  const plot = event.target.closest(".expandable-chart .shiny-plot-output");
  if (!plot || !plot.querySelector("img")) return;
  const card = plot.closest(".expandable-chart");
  if (card.getAttribute("data-full-screen") === "true") return;
  const expand = card.querySelector(".bslib-full-screen-enter");
  if (expand) expand.click();
});
