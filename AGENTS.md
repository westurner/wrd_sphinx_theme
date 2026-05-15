# AI Agent Instructions for wrd-sphinx-theme

Welcome, AI Agent! This document acts as the core context and instruction reference for the `wrd-sphinx-theme` project. It describes the structure, how to build/run the application, and standard procedures for testing.

## Overview
- This project is a custom Sphinx documentation theme based on `sphinxjp.themes.basicstrap` (Bootstrap).
- Modifying CSS, JS, or HTML Jinja templates requires rebuilding the documentation to see changes.
- Ensure any generated files or additions remain consistent with standard Python, Sphinx theme, and Bootstrap conventions.

## Repository Structure Overview
- `wrd_sphinx_theme/`: The core directory containing the theme assets (CSS, JS, Jinja HTML templates).
- `docs/`: The Sphinx documentation for the theme itself.
- `tests/`: Contains Python unit tests (`pytest`).
- `Dockerfile.e2e` & `.devcontainer/`: Setup for DevContainers to run E2E browser tests via Playwright, providing tools and browsers like Chromium and Firefox.
- `Makefile`: Python lifecycle and testing commands (located in the root).

## Common Commands & Workflows

### Building the Documentation
Documentation generation uses Sphinx. When you edit the theme files in `wrd_sphinx_theme/`, rebuild to test your visual changes.

When editing split JS/CSS files within `wrd_sphinx_theme/template/static/`, you need to concatenate them into `local.js` and `local.css`.
- **`make localcss localjs`**: Compiles and combines individual CSS and JS files into the main injected `local.css` and `local.js` files.
- **`make local-live`** (or `make localcss-live localjs-live`): Runs the concatenation and copies the resulting files directly into the active Sphinx `_build/html/_static/` or `_build/singlehtml/_static/` output directories. This is useful for injecting style changes to a running live server without requiring a full `make html` re-run.

For a full rebuild:
```bash
make localcss localjs
cd docs/
make clean
make html
```
> The generated documentation will be available in `docs/_build/html/`.

### Running Tests

This project enforces multiple levels of testing to prevent regressions.

**1. Python Unit Tests & Linting:**
Run the standard test suite via the top-level `Makefile`:
```bash
# Run flake8 linter
make lint

# Run unit tests via pytest
make test

# Run tests across all Python environments using tox
make test-all

# Generate code coverage
make coverage
```

**2. E2E Tests (Playwright):**
The repository supports Playwright E2E tests for browser UI verification. These are run inside the configured DevContainer.
- To execute them manually (if an `e2e` folder or node project exists), verify Node dependencies are installed via `npm install` and run standard Playwright commands:
```bash
npx playwright test
```
- Or run a specific browser test setup:
```bash
npx playwright test --project=chromium
```

### DevContainer & Environment
When working in VS Code via the DevContainer (`.devcontainer/devcontainer.json` + `Dockerfile.e2e`), you will have Node.js, Playwright system dependencies, and MCP integrations (like `chrome-devtools-mcp` or `firefox-devtools-mcp`) explicitly preconfigured. System tools like `rg`, `jq`, and `unzip` are available for deep searches.

### Key Rules
- Avoid caching issues: ALWAYS run `make clean` before `make html` when making Jinja/CSS changes.
- Tests (both unit and Playwright e2e) must be updated or added when creating new theme features.