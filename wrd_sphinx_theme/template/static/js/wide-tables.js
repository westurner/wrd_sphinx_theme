(function () {
  "use strict";

  /** Read a supported table into headers and rows, or return a validation error. */
  function readGrid(table) {
    var allRows = Array.from(table.rows);
    var headerRows = table.tHead ? Array.from(table.tHead.rows) : [];
    var headerRow = headerRows[0];

    if (!table.tHead && allRows[0] && Array.from(allRows[0].cells).every(function (cell) {
      return cell.tagName === "TH";
    })) {
      headerRow = allRows[0];
    }

    if (!headerRow || headerRows.length > 1 || (table.tFoot && table.tFoot.rows.length)) {
      return {error: "requires one header row and no footer"};
    }

    var headers = Array.from(headerRow.cells);
    var rows = allRows.filter(function (row) {
      return row !== headerRow;
    }).map(function (row) {
      return Array.from(row.cells);
    });

    if (headers.length < 2 || !rows.length) {
      return {error: "requires at least two columns and one data row"};
    }

    var cells = headers.concat.apply(headers.slice(), rows);
    if (cells.some(function (cell) {
      return cell.colSpan !== 1 || cell.rowSpan !== 1;
    })) {
      return {error: "rowspan and colspan cells are not supported"};
    }

    if (rows.some(function (row) {
      return row.length !== headers.length;
    })) {
      return {error: "rows do not have a consistent number of columns"};
    }

    return {headers: headers, rows: rows};
  }

  /** Clone a cell's contents into another element, removing duplicate IDs. */
  function appendCellContents(target, source) {
    Array.from(source.childNodes).forEach(function (child) {
      var clone = child.cloneNode(true);
      if (clone.nodeType === 1) {
        clone.removeAttribute("id");
        clone.querySelectorAll("[id]").forEach(function (element) {
          element.removeAttribute("id");
        });
      }
      target.appendChild(clone);
    });
  }

  /** Build a replacement cell with copied attributes, scope, and contents. */
  function makeCell(source, tagName, scope) {
    var cell = document.createElement(tagName);
    Array.from(source.attributes).forEach(function (attribute) {
      if (!["id", "colspan", "rowspan", "scope"].includes(attribute.name)) {
        cell.setAttribute(attribute.name, attribute.value);
      }
    });
    if (scope) cell.setAttribute("scope", scope);
    appendCellContents(cell, source);
    return cell;
  }

  /** Create a transposed table, or return the validation error from readGrid. */
  function transposedTable(source) {
    var grid = readGrid(source);
    if (grid.error) return grid;

    var table = document.createElement("table");
    Array.from(source.attributes).forEach(function (attribute) {
      if (attribute.name !== "id" && attribute.name !== "hidden") {
        table.setAttribute(attribute.name, attribute.value);
      }
    });

    if (source.caption) {
      var caption = document.createElement("caption");
      appendCellContents(caption, source.caption);
      table.appendChild(caption);
    }

    var head = document.createElement("thead");
    var header = document.createElement("tr");
    header.appendChild(makeCell(grid.headers[0], "th", "col"));
    grid.rows.forEach(function (row) {
      header.appendChild(makeCell(row[0], "th", "col"));
    });
    head.appendChild(header);
    table.appendChild(head);

    var body = document.createElement("tbody");
    for (var column = 1; column < grid.headers.length; column += 1) {
      var row = document.createElement("tr");
      row.appendChild(makeCell(grid.headers[column], "th", "row"));
      grid.rows.forEach(function (cells) {
        row.appendChild(makeCell(cells[column], "td", null));
      });
      body.appendChild(row);
    }
    table.appendChild(body);
    return {table: table};
  }

  /** Create a list-style outline for a table, or return its validation error. */
  function outlineTable(source) {
    var grid = readGrid(source);
    if (grid.error) return grid;

    var outline = document.createElement("div");
    outline.className = "table-outline";
    outline.setAttribute("role", "list");

    if (source.caption) {
      var caption = document.createElement("div");
      caption.className = "table-outline__caption";
      appendCellContents(caption, source.caption);
      outline.appendChild(caption);
    }

    grid.rows.forEach(function (row) {
      var item = document.createElement("section");
      item.className = "table-outline__item";
      item.setAttribute("role", "listitem");

      var title = document.createElement("h3");
      title.className = "table-outline__title";
      appendCellContents(title, row[0]);
      item.appendChild(title);

      var fields = document.createElement("dl");
      fields.className = "table-outline__fields";
      for (var column = 1; column < grid.headers.length; column += 1) {
        var field = document.createElement("div");
        field.className = "table-outline__field";
        var name = document.createElement("dt");
        var value = document.createElement("dd");
        appendCellContents(name, grid.headers[column]);
        appendCellContents(value, row[column]);
        field.append(name, value);
        fields.appendChild(field);
      }
      item.appendChild(fields);
      outline.appendChild(item);
    });
    return {view: outline};
  }

  /** Update a view button's pressed state for assistive technology. */
  function setPressed(button, pressed) {
    button.setAttribute("aria-pressed", String(pressed));
  }

  /** Briefly highlight a rejected view and report why it is unsupported. */
  function rejectView(button, table, error) {
    button.classList.remove("table-view-toggle--strobe");
    void button.offsetWidth;
    button.classList.add("table-view-toggle--strobe");
    window.setTimeout(function () {
      button.classList.remove("table-view-toggle--strobe");
    }, 700);
    console.warn("wrd_sphinx_theme: table view is unsupported: " + error, table);
  }

  /** Add table controls and manage their width, outline, and transpose states. */
  function addControls(wrapper, table, label) {
    var controls = document.createElement("div");
    controls.className = "table-controls";
    controls.setAttribute("role", "group");
    controls.setAttribute(
      "aria-label",
      "Display options for " + (label?.textContent.trim() || "data table")
    );

    var wideButton = document.createElement("button");
    wideButton.type = "button";
    wideButton.className = "table-wide-toggle";
    wideButton.textContent = "Widen table";
    wideButton.setAttribute("aria-expanded", "false");

    var outlineButton = document.createElement("button");
    outlineButton.type = "button";
    outlineButton.className = "table-view-toggle";
    outlineButton.textContent = "Outline";
    outlineButton.setAttribute("aria-label", "Show table as an outline");
    setPressed(outlineButton, false);

    var transposeButton = document.createElement("button");
    transposeButton.type = "button";
    transposeButton.className = "table-view-toggle";
    transposeButton.textContent = "Transpose";
    transposeButton.setAttribute("aria-label", "Transpose table");
    setPressed(transposeButton, false);

    controls.append(wideButton, outlineButton, transposeButton);
    wrapper.parentNode.insertBefore(controls, wrapper);

    var presentation = document.createElement("div");
    presentation.className = "table-view-output";
    presentation.setAttribute("aria-live", "polite");
    presentation.hidden = true;
    wrapper.appendChild(presentation);

    var state = {wide: false, outline: false, transposed: false};

  /** Measure the remaining viewport width and expose it as a CSS variable. */
    function measureAvailableWidth() {
      var left = Math.max(0, wrapper.getBoundingClientRect().left);
      var available = Math.max(0, document.documentElement.clientWidth - left);
      wrapper.style.setProperty("--wrd-table-available-width", available + "px");
    }

    /** Render the selected table view, returning a control and error on failure. */
    function render() {
      if (!state.outline && !state.transposed) {
        table.hidden = false;
        presentation.hidden = true;
        presentation.replaceChildren();
        return;
      }

      var activeTable = table;
      if (state.transposed) {
        var result = transposedTable(table);
        if (result.error) return {button: transposeButton, error: result.error};
        activeTable = result.table;
      }

      var view = activeTable;
      if (state.outline) {
        var outline = outlineTable(activeTable);
        if (outline.error) return {button: outlineButton, error: outline.error};
        view = outline.view;
      }

      table.hidden = true;
      presentation.replaceChildren(view);
      presentation.hidden = false;
      return null;
    }

    wideButton.addEventListener("click", function () {
      state.wide = !state.wide;
      wrapper.classList.toggle("table-responsive--wide", state.wide);
      if (state.wide) measureAvailableWidth();
      wideButton.textContent = state.wide ? "Restore table width" : "Widen table";
      wideButton.setAttribute("aria-expanded", String(state.wide));
      wrapper.scrollLeft = 0;
    });

    window.addEventListener("resize", function () {
      if (state.wide) measureAvailableWidth();
    });

    outlineButton.addEventListener("click", function () {
      state.outline = !state.outline;
      setPressed(outlineButton, state.outline);
      var failure = render();
      if (failure) {
        state.outline = false;
        setPressed(outlineButton, false);
        rejectView(failure.button, table, failure.error);
        render();
      }
    });

    transposeButton.addEventListener("click", function () {
      if (!state.transposed) {
        var result = transposedTable(table);
        if (result.error) {
          rejectView(transposeButton, table, result.error);
          return;
        }
      }
      state.transposed = !state.transposed;
      setPressed(transposeButton, state.transposed);
      var failure = render();
      if (failure) {
        state.transposed = false;
        setPressed(transposeButton, false);
        rejectView(failure.button, table, failure.error);
        render();
      }
    });
  }

  /** Add accessible view controls to every unenhanced responsive table. */
  function enhanceWideTables() {
    document.querySelectorAll(".table-responsive").forEach(function (wrapper) {
      var table = wrapper.querySelector("table.docutils");
      if (!table) return;
      if (wrapper.previousElementSibling?.classList.contains("table-controls")) return;

      table.classList.forEach(function (className) {
        if (className.indexOf("wrd-table-") === 0) {
          wrapper.classList.add(className);
        }
      });

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
      addControls(wrapper, table, label);
    });
  }

  /** Wait for MathJax startup when present, then enhance responsive tables. */
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