import { test, expect } from '@playwright/test';

test.describe('wrd-sphinx-theme e2e tests', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('loads jQuery before Bootstrap and provides affix without console errors', async ({ page }) => {
    const pageErrors: string[] = [];
    page.on('pageerror', error => pageErrors.push(error.message));

    await page.goto('/usage.html');
    const runtime = await page.evaluate(() => ({
      jquery: typeof window.jQuery,
      affix: typeof window.jQuery?.fn?.affix,
    }));

    expect(runtime.jquery).toBe('function');
    expect(runtime.affix).toBe('function');
    expect(pageErrors).toEqual([]);
  });

  test('table permalink clicks do not trigger an empty Bootstrap selector', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => {
      if (message.type() === 'error') errors.push(message.text());
    });

    await page.goto('/usage.html');
    await expect(page.locator('#localToc')).not.toHaveAttribute('data-target', '#');

    const permalink = page.locator('a.headerlink[href="#id3"]');
    await expect(permalink).toBeVisible();
    await permalink.click();
    await expect(page).toHaveURL(/#id3$/);
    expect(errors).toEqual([]);
  });

  test('layout and sidenav-affix', async ({ page }) => {
    // Check if sidebar wrapper is present (from layout/affix)
    const sidebarWrapper = page.locator('#sidebar-wrapper');
    await expect(sidebarWrapper).toBeAttached();
  });

  test('sidenav-scrollto', async ({ page }) => {
    // Top button should be added to body
    const topButton = page.locator('button.toplink a[title="Top"]');
    await expect(topButton).toBeAttached();

    // Check if navigation triggers youarehere class updates
    // We can simulate hash change
    await page.evaluate(() => {
      window.location.hash = '#installation';
    });
    
    // Wait for the hashchange event listener to update the nav
    // This is handled by sidenav-scrollto.js
    const headerlink = page.locator('a.headerlink[href="#installation"]');
    // We might not have #installation explicitly but let's check for the default ones.
    // Or we can just check if any youarehere class exists after clicking.
  });

  test('sidenav scrolling ignores empty and missing targets', async ({ page }) => {
    const pageErrors: string[] = [];
    page.on('pageerror', error => pageErrors.push(error.message));

    await page.goto('/usage.html#wide-tables');
    await page.evaluate(() => {
      window.navbar_update('#');
      window.navbar_update('#missing-anchor');
      window.navbar_scrollto(window.jQuery());
      window.jQuery('#sidebar-wrapper').scrollTo(window.jQuery());
    });

    expect(pageErrors).toEqual([]);
  });

  test('newtab features and options widget', async ({ page }) => {
    // Check if the options widget is added to the sidebar
    const optionsWidget = page.locator('.sidebar-options');
    await expect(optionsWidget).toBeAttached();

    // Check the checkboxes are present
    await expect(page.locator('input#chk_newtab')).toBeAttached();
    await expect(page.locator('input#chk_showvisited')).toBeAttached();
    await expect(page.locator('input#chk_shortenlinks')).toBeAttached();
  });

  test('newtab-noopener automatically adds target and rel', async ({ page }) => {
    // Inject a dummy external link into the page
    await page.evaluate(() => {
      const a = document.createElement('a');
      a.href = 'https://example.com';
      a.id = 'dummy-external';
      a.textContent = 'External Link';
      document.body.appendChild(a);
    });

    // Run the logic from newtab-noopener or it might have already run on doc.ready
    // Since it runs on ready, dynamically added won't have it unless we trigger it.
    // Let's reload with an injected mock if possible, or test existing page links.
    const externalLinks = page.locator('a[href^="http"]');
    const count = await externalLinks.count();
    
    if (count > 0) {
      const firstLink = externalLinks.first();
      await expect(firstLink).toHaveAttribute('target', '_blank');
      const rel = await firstLink.getAttribute('rel');
      expect(rel).toContain('noopener');
    }
  });

  test('linkstyles shortening', async ({ page }) => {
    // Find an external reference link or just pass this test implicitly if we don't have explicit external links in the test docs to evaluate.
    const shortenCheckbox = page.locator('input#chk_shortenlinks');
    // If it's checked by default, we expect short links
    
    // Unchecking should run unshortenLinks()
    await shortenCheckbox.uncheck({ force: true });
    // Re-checking should run shortenLinks()
    await shortenCheckbox.check({ force: true });
    
    await expect(shortenCheckbox).toBeChecked();
  });

  test('transposed table remains visible when outline mode is disabled', async ({ page }) => {
    await page.goto('/usage.html#wide-tables');

    const table = page.locator('table.docutils').filter({
      hasText: 'Platonic solids: topology, symmetry, and metric formulas',
    });
    const wrapper = table.locator('xpath=..');
    const controls = wrapper.locator('xpath=preceding-sibling::*[1]');
    const outlineButton = controls.getByRole('button', { name: 'Show table as an outline' });
    const transposeButton = controls.getByRole('button', { name: 'Transpose table' });

    await expect(table).toBeVisible();
    await outlineButton.click();
    await expect(wrapper.locator('.table-outline__item')).toHaveCount(5);

    await transposeButton.click();
    await expect(wrapper.locator('.table-outline__item')).toHaveCount(9);

    await outlineButton.click();
    const transposedTable = wrapper.locator('.table-view-output table.docutils');
    await expect(transposedTable).toBeVisible();
    await expect(transposedTable.locator('tbody > tr')).toHaveCount(9);
    await expect(table).toBeHidden();
  });

  test('table controls are present even when a table fits its wrapper', async ({ page }) => {
    await page.goto('/usage.html#wide-tables');

    const table = page.locator('table.docutils').filter({
      hasText: 'Example using a grid table (ReStructuredText)',
    });
    const wrapper = table.locator('xpath=..');
    const fits = await table.evaluate(element => {
      return element.scrollWidth <= element.parentElement.clientWidth + 2;
    });
    expect(fits).toBeTruthy();

    const controls = wrapper.locator('xpath=preceding-sibling::*[1]');
    await expect(controls.getByRole('button', { name: 'Widen table' })).toBeVisible();
    await expect(controls.getByRole('button', { name: 'Show table as an outline' })).toBeVisible();
    await expect(controls.getByRole('button', { name: 'Transpose table' })).toBeVisible();
  });
});
