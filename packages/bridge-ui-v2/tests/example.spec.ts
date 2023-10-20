import { expect, test } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto('http://localhost:4173');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/Taiko Bridge/);
});
