document.addEventListener("DOMContentLoaded", async () => {
  SKBags.initializeShell("home");

  try {
    const [meta, orders, items] = await Promise.all([
      SKBags.apiRequest("/api/meta"),
      SKBags.apiRequest("/api/orders?page=1&pageSize=1"),
      SKBags.apiRequest("/api/items?page=1&pageSize=1"),
    ]);

    document.getElementById("homeDatabase").textContent = meta.database;
    document.getElementById("homeOrdersCount").textContent = SKBags.formatNumber(orders.pagination.totalCount);
    document.getElementById("homeItemsCount").textContent = SKBags.formatNumber(items.pagination.totalCount);
  } catch (_error) {
    document.getElementById("homeOrdersCount").textContent = "Unavailable";
    document.getElementById("homeItemsCount").textContent = "Unavailable";
  }
});
