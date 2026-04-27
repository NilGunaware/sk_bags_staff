document.addEventListener("DOMContentLoaded", async () => {
  SKBags.initializeShell("home");

  const refs = {
    database: document.getElementById("homeDatabase"),
    ordersCount: document.getElementById("homeOrdersCount"),
    itemsCount: document.getElementById("homeItemsCount"),
    priceCategoriesMeta: document.getElementById("homePriceCategoriesMeta"),
    priceCategoriesPanel: document.getElementById("homePriceCategoriesPanel"),
    lookupForm: document.getElementById("homeLookupForm"),
    lookupMeta: document.getElementById("homeLookupMeta"),
    lookupPanel: document.getElementById("homeLookupPanel"),
    lookupCode: document.getElementById("homeLookupCode"),
    lookupQr: document.getElementById("homeLookupQr"),
    lookupName: document.getElementById("homeLookupName"),
  };

  refs.lookupForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    await runLookup();
  });

  try {
    const [meta, orders, items, priceCategories] = await Promise.all([
      SKBags.apiRequest("/api/meta"),
      SKBags.apiRequest("/api/orders?page=1&pageSize=1"),
      SKBags.apiRequest("/api/items?page=1&pageSize=1"),
      SKBags.apiRequest("/api/price-categories"),
    ]);

    refs.database.textContent = meta.database;
    refs.ordersCount.textContent = SKBags.formatNumber(orders.pagination.totalCount);
    refs.itemsCount.textContent = SKBags.formatNumber(items.pagination.totalCount);
    refs.priceCategoriesMeta.textContent = `${priceCategories.data.length} category(s)`;
    refs.priceCategoriesPanel.innerHTML = SKBags.renderPriceCategories(
      priceCategories.data,
      "No active price categories found.",
    );
  } catch (_error) {
    refs.ordersCount.textContent = "Unavailable";
    refs.itemsCount.textContent = "Unavailable";
    refs.priceCategoriesMeta.textContent = "Unavailable";
    refs.priceCategoriesPanel.innerHTML =
      `<p class="message-slot is-error">Price category list is unavailable right now.</p>`;
  }

  async function runLookup() {
    const code = refs.lookupCode.value.trim();
    const qr = refs.lookupQr.value.trim();
    const name = refs.lookupName.value.trim();
    const lookup = qr || code;

    refs.lookupMeta.textContent = "Searching...";
    refs.lookupPanel.innerHTML = `<p class="muted-copy">Loading item detail...</p>`;

    try {
      if (lookup) {
        const response = await SKBags.apiRequest(`/api/items/detail/${encodeURIComponent(lookup)}`);
        refs.lookupMeta.textContent = `Loaded ${response.data.itemCode || lookup}`;
        refs.lookupPanel.innerHTML = SKBags.renderItemDetail(response.data);
        return;
      }

      if (name) {
        const list = await SKBags.apiRequest(`/api/items?${SKBags.buildQuery({ itemName: name, page: 1, pageSize: 1 })}`);
        const firstItem = list.data[0];
        if (!firstItem) {
          throw new Error("No item matched the supplied item name.");
        }
        const response = await SKBags.apiRequest(`/api/items/detail/${encodeURIComponent(firstItem.itemCode)}`);
        refs.lookupMeta.textContent = `Loaded ${response.data.itemCode || firstItem.itemCode}`;
        refs.lookupPanel.innerHTML = SKBags.renderItemDetail(response.data);
        return;
      }

      throw new Error("Enter item code, QR code, or item name to search.");
    } catch (error) {
      refs.lookupMeta.textContent = "Lookup failed";
      refs.lookupPanel.innerHTML = `<p class="message-slot is-error">${SKBags.escapeHtml(error.message)}</p>`;
    }
  }
});
