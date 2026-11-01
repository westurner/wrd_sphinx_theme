=====
Usage
=====

To use WRD Sphinx Theme in a Sphinx project, set ``html_theme`` in
``conf.py``::

    html_theme = ['wrd_sphinx_theme']

Example
=========

Nested
--------

Headers
~~~~~~~

Paragraph of text 1.

* This is a top-level list item

  * This is a nested list item

    * This is a nested nested list item

      With additional text here

    * Another nested nested list item

      And text

  * Item

* Another item

Paragraph of text 2.


Paragraph of text 3.

* This is a top-level list item

  * This is a nested list item

    * This is a nested nested list item
    * Another nested nested list item

  * Item

* Another item

Paragraph of text 4.

Wide Tables
===========

Every responsive table receives ``Widen table``, ``Outline``, and ``Transpose``
controls, even if it currently fits its content column. Widen table expands the
wrapper when more room is useful. Outline and Transpose are independent;
enabling both shows an outline of the transposed table. Tables with multiple
header rows, irregular rows, or merged cells cannot be transposed. In that
case the Transpose control briefly strobes and the browser console explains
why.

In reStructuredText, add utility classes with the ``:class:`` option on a
``table`` or ``list-table`` directive:

This Platonic-solids comparison is intentionally wide. Its formulas use edge
length ``a``; the Euler characteristic is for each solid's boundary surface.

.. list-table:: Platonic solids: topology, symmetry, and metric formulas
   :header-rows: 1
   :class: wrd-table-wide-90 wrd-table-compact

   * - Solid
     - Schlaefli symbol
     - Dimension
     - Vertices
     - Edges
     - Faces
     - Boundary Euler characteristic
     - Full symmetry group
     - Surface area
     - Volume
   * - Regular tetrahedron
     - :math:`\{3, 3\}`
     - :math:`3`
     - 4
     - 6
     - 4
     - :math:`\chi = 2`
     - :math:`T_d,\ |T_d| = 24`
     - :math:`\sqrt{3}\,a^2`
     - :math:`\frac{a^3}{6\sqrt{2}}`
   * - Cube
     - :math:`\{4, 3\}`
     - :math:`3`
     - 8
     - 12
     - 6
     - :math:`\chi = 2`
     - :math:`O_h,\ |O_h| = 48`
     - :math:`6a^2`
     - :math:`a^3`
   * - Regular octahedron
     - :math:`\{3, 4\}`
     - :math:`3`
     - 6
     - 12
     - 8
     - :math:`\chi = 2`
     - :math:`O_h,\ |O_h| = 48`
     - :math:`2\sqrt{3}\,a^2`
     - :math:`\frac{\sqrt{2}\,a^3}{3}`
   * - Regular dodecahedron
     - :math:`\{5, 3\}`
     - :math:`3`
     - 20
     - 30
     - 12
     - :math:`\chi = 2`
     - :math:`I_h,\ |I_h| = 120`
     - :math:`3\sqrt{25 + 10\sqrt{5}}\,a^2`
     - :math:`\frac{(15 + 7\sqrt{5})a^3}{4}`
   * - Regular icosahedron
     - :math:`\{3, 5\}`
     - :math:`3`
     - 12
     - 30
     - 20
     - :math:`\chi = 2`
     - :math:`I_h,\ |I_h| = 120`
     - :math:`5\sqrt{3}\,a^2`
     - :math:`\frac{5(3 + \sqrt{5})a^3}{12}`

.. table:: Example using a grid table (ReStructuredText)

   +-----------+---------------+------------------------------+
   | Parameter | Typical value | Notes                        |
   +===========+===============+==============================+
   | Width     | 80vw          | Capped to available viewport |
   +-----------+---------------+------------------------------+

.. list-table:: Example using a list-table (ReStructuredText)
   :header-rows: 1

   * - Parameter
     - Value
     - Notes
   * - Cell padding
     - Roomy
     - Can be transposed if the rows are rectangular

The same classes work with MyST Markdown pipe tables with an attribute block::

    | Parameter | Value |
    | --- | --- |
    | Width | 80vw |
    {: .wrd-table-wide-80 .wrd-table-compact}

For MyST Markdown ``list-table`` directives, put ``:class:`` alongside the other
directive options:

::

    ```{list-table} Example MyST list-table
    :header-rows: 1
    :class: wrd-table-wide-90 wrd-table-roomy

    * - Parameter
      - Value
      - Notes
    * - Cell padding
      - Roomy
      - Can be transposed when rows are rectangular
    ```

CSS Configuration
-----------------

Override the theme variables in a project stylesheet to tune all wide tables::

    :root {
      --wrd-table-wide-width: min(84vw, 1500px);
      --wrd-table-mobile-gutter: 16px;
      --wrd-table-control-bg: #fff;
      --wrd-table-control-color: #263238;
      --wrd-table-control-border: #607d8b;
      --wrd-table-control-hover-bg: #eceff1;
      --wrd-table-control-active-bg: #176b87;
      --wrd-table-control-active-color: #fff;
      --wrd-table-control-padding: 0.4rem 0.7rem;
      --wrd-table-control-font-size: 0.9rem;
      --wrd-table-control-radius: 4px;
      --wrd-table-cell-padding: 0.4rem;
      --wrd-table-outline-gap: 1rem;
    }

  The utility classes follow a utility-first pattern: ``wrd-table-wide-80`` and
  ``wrd-table-wide-90`` set preferred widths; ``wrd-table-compact`` and
  ``wrd-table-roomy`` set cell padding; ``wrd-table-controls-primary`` and
  ``wrd-table-controls-muted`` choose button palettes; and
  ``wrd-table-controls-large`` increases button size. Preferred widths are
  capped to the remaining viewport space so they do not widen the page itself.
  Add any ``wrd-table-controls-*`` class to the directive's existing
  ``:class:`` option to style its buttons. CSS variables can override these
  defaults globally or on individual wrappers.
