(function () {
  "use strict";

  function enhanceWideTables() {
    document.querySelectorAll(".table-responsive").forEach(function (wrapper) {
      var table = wrapper.querySelector("table.docutils");
      if (!table || table.scrollWidth <= wrapper.clientWidth + 2) return;

      var label = table.querySelector("caption");
      if (!label) {
        label = wrapper.closest("section")?.querySelector("h1, h2, h3, h4, h5, h6");
      }

      wrapper.setAttribute("role", "region");
      wrapper.setAttribute("tabindex", "0");
      wrapper.setAttribute(
        "aria-label",
        "Scrollable table: " + (label?.textContent.trim() || "data table")
      );

      var button = document.createElement("button");
      button.type = "button";
      button.className = "table-wide-toggle";
      button.textContent = "Widen table";
      button.setAttribute("aria-expanded", "false");

      wrapper.parentNode.insertBefore(button, wrapper);
      button.addEventListener("click", function () {
        var expanded = wrapper.classList.toggle("table-responsive--wide");
        button.textContent = expanded ? "Restore table width" : "Widen table";
        button.setAttribute("aria-expanded", String(expanded));
        wrapper.scrollLeft = 0;
      });
    });
  }

  function afterMathJax() {
    var promise = window.MathJax?.startup?.promise;
    if (promise && typeof promise.then === "function") {
      promise.then(enhanceWideTables, enhanceWideTables);
    } else {
      enhanceWideTables();
    }
  }

  if (document.readyState === "complete") {
    afterMathJax();
  } else {
    window.addEventListener("load", afterMathJax, {once: true});
  }
})();