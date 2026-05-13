document.addEventListener("DOMContentLoaded", async () => {
  SKBags.initializeShell("items");

  const refs = {
    form: document.getElementById("itemsFilterForm"),
    resetBtn: document.getElementById("itemsResetBtn"),
    tableBody: document.getElementById("itemsTableBody"),
    meta: document.getElementById("itemsMeta"),
    priceCategoriesMeta: document.getElementById("itemsPriceCategoriesMeta"),
    priceCategoriesPanel: document.getElementById("itemsPriceCategoriesPanel"),
    qrStatusChip: document.getElementById("qrStatusChip"),
    detailMeta: document.getElementById("itemDetailMeta"),
    detailPanel: document.getElementById("itemDetailPanel"),
    draftSummaryChip: document.getElementById("draftSummaryChip"),
    paginationText: document.getElementById("itemsPaginationText"),
    prevBtn: document.getElementById("itemsPrevBtn"),
    nextBtn: document.getElementById("itemsNextBtn"),
    itemCode: document.getElementById("itemsItemCode"),
    itemName: document.getElementById("itemsItemName"),
    qrCode: document.getElementById("itemsQrCode"),
    pageSize: document.getElementById("itemsPageSize"),
  };

  const state = {
    page: 1,
    pageSize: 10,
    selectedLookup: "",
    filters: {
      itemCode: "",
      itemName: "",
      qrCode: "",
    },
    pagination: null,
  };

  refs.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    syncFilters();
    state.page = 1;
    await loadItems();
  });

  refs.resetBtn.addEventListener("click", async () => {
    state.page = 1;
    state.pageSize = 10;
    state.selectedLookup = "";
    state.filters = {
      itemCode: "",
      itemName: "",
      qrCode: "",
    };
    refs.form.reset();
    refs.pageSize.value = "10";
    refs.detailMeta.textContent = "Waiting...";
    refs.detailPanel.innerHTML = `<p class="muted-copy">Select an item row to load complete BUSY detail.</p>`;
    await loadItems();
  });

  refs.prevBtn.addEventListener("click", async () => {
    if (state.page > 1) {
      state.page -= 1;
      await loadItems();
    }
  });

  refs.nextBtn.addEventListener("click", async () => {
    if (state.pagination && state.page < state.pagination.totalPages) {
      state.page += 1;
      await loadItems();
    }
  });

  await loadPriceCategories();
  await loadItems();

  async function loadPriceCategories() {
    refs.priceCategoriesMeta.textContent = "Loading...";
    refs.priceCategoriesPanel.innerHTML = `<p class="muted-copy">Loading price categories...</p>`;

    try {
      const response = await SKBags.apiRequest("/api/price-categories");
      refs.priceCategoriesMeta.textContent = `${response.data.length} category(s)`;
      refs.priceCategoriesPanel.innerHTML = SKBags.renderPriceCategories(
        response.data,
        "No active price categories found.",
      );
    } catch (_error) {
      refs.priceCategoriesMeta.textContent = "Unavailable";
      refs.priceCategoriesPanel.innerHTML =
        `<p class="message-slot is-error">Price category list is unavailable right now.</p>`;
    }
  }

  function syncFilters() {
    state.pageSize = Number(refs.pageSize.value || 10);
    state.filters = {
      itemCode: refs.itemCode.value.trim(),
      itemName: refs.itemName.value.trim(),
      qrCode: refs.qrCode.value.trim(),
    };
  }

  function syncDraftSummary() {
    refs.draftSummaryChip.textContent = `Draft ${SKBags.getDraft().length}`;
  }

  async function loadItems() {
    refs.tableBody.innerHTML = `<tr><td class="empty" colspan="7">Loading items...</td></tr>`;
    refs.meta.textContent = "Loading...";
    refs.qrStatusChip.textContent = "Waiting...";
    syncDraftSummary();

    try {
      const query = SKBags.buildQuery({
        page: state.page,
        pageSize: state.pageSize,
        ...state.filters,
      });
      const response = await SKBags.apiRequest(`/api/items?${query}`);
      state.pagination = response.pagination;

      refs.meta.textContent = `${response.pagination.totalCount} item(s)`;
      refs.qrStatusChip.textContent = response.filters.qrCodeAvailable
        ? "QR lookup enabled"
        : "QR not available in DB";
      refs.paginationText.textContent = buildPagerText(response.pagination);
      refs.prevBtn.disabled = response.pagination.page <= 1;
      refs.nextBtn.disabled = response.pagination.page >= response.pagination.totalPages;

      if (!response.data.length) {
        refs.tableBody.innerHTML = `<tr><td class="empty" colspan="8">No items matched the current filters.</td></tr>`;
        return;
      }

      refs.tableBody.innerHTML = response.data
        .map((item) => {
          const imageBlock =
            item.image && item.image.available && item.image.url
              ? `
                <button
                  class="item-thumb-button"
                  type="button"
                  data-image-preview-url="${SKBags.escapeAttribute(item.image.url)}"
                  data-image-preview-title="${SKBags.escapeAttribute(item.itemName)}"
                >
                  <img
                    class="item-thumb"
                    src="${SKBags.escapeAttribute(item.image.url)}"
                    alt="${SKBags.escapeAttribute(item.itemName)}"
                    onerror="this.style.display='none'; this.nextElementSibling.style.display='grid';"
                  />
                  <span class="item-thumb item-thumb-empty" style="display:none;">No image</span>
                </button>
              `
              : `<span class="item-thumb item-thumb-empty">No image</span>`;
          return `
            <tr data-item-lookup="${SKBags.escapeAttribute(item.itemCode || item.qrCode || "")}">
              <td>${imageBlock}</td>
              <td>${SKBags.escapeHtml(item.itemCode || "-")}</td>
              <td>${SKBags.escapeHtml(item.itemName)}</td>
              <td>${SKBags.escapeHtml(item.itemGroup || "-")}</td>
              <td>${SKBags.formatNumber(item.itemQuantity)}</td>
              <td>${SKBags.formatNumber(item.priceCount || 0)}</td>
              <td>${SKBags.formatPriceRange(item.minFinalPrice, item.maxFinalPrice)}</td>
              <td>
                <div class="action-row">
                  <button class="btn btn-secondary" type="button" data-open="${SKBags.escapeAttribute(
                    item.itemCode || item.qrCode || "",
                  )}">Open Detail</button>
                  <button class="btn btn-secondary" type="button" data-add='${SKBags.escapeAttribute(
                    JSON.stringify({
                      itemCode: item.itemCode || "",
                      itemName: item.itemName || "",
                      quantity: 1,
                    }),
                  )}'>Add To Draft</button>
                </div>
              </td>
            </tr>
          `;
        })
        .join("");

      refs.tableBody.querySelectorAll("[data-add]").forEach((button) => {
        button.addEventListener("click", () => {
          const payload = JSON.parse(button.dataset.add);
          SKBags.addDraftItem(payload);
          syncDraftSummary();
          refs.meta.textContent = `${response.pagination.totalCount} item(s) • Added ${payload.itemCode || payload.itemName}`;
        });
      });

      refs.tableBody.querySelectorAll("[data-open]").forEach((button) => {
        button.addEventListener("click", async () => {
          const lookup = button.dataset.open;
          if (!lookup) {
            return;
          }
          state.selectedLookup = lookup;
          await loadItemDetail(lookup);
        });
      });

      if (!state.selectedLookup && response.data[0]?.itemCode) {
        state.selectedLookup = response.data[0].itemCode;
        await loadItemDetail(state.selectedLookup);
      }
    } catch (error) {
      refs.meta.textContent = "Items unavailable";
      refs.qrStatusChip.textContent = "Request failed";
      refs.paginationText.textContent = "No results";
      refs.prevBtn.disabled = true;
      refs.nextBtn.disabled = true;
      refs.tableBody.innerHTML = `<tr><td class="empty" colspan="7">${SKBags.escapeHtml(error.message)}</td></tr>`;
    }
  }

  async function loadItemDetail(lookup) {
    refs.detailMeta.textContent = `Loading ${lookup}`;
    refs.detailPanel.innerHTML = `<p class="muted-copy">Loading complete item detail...</p>`;

    try {
      const response = await SKBags.apiRequest(`/api/items/detail/${encodeURIComponent(lookup)}`);
      refs.detailMeta.textContent = `Loaded ${response.data.itemCode || lookup}`;
      refs.detailPanel.innerHTML = SKBags.renderItemDetail(response.data);
    } catch (error) {
      refs.detailMeta.textContent = "Detail unavailable";
      refs.detailPanel.innerHTML = `<p class="message-slot is-error">${SKBags.escapeHtml(error.message)}</p>`;
    }
  }

  function buildPagerText(pagination) {
    if (!pagination.totalPages) {
      return "No results";
    }
    return `Page ${pagination.page} of ${pagination.totalPages} • ${pagination.totalCount} result(s)`;
  }
});
