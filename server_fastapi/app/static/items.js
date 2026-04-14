document.addEventListener("DOMContentLoaded", async () => {
  SKBags.initializeShell("items");

  const refs = {
    form: document.getElementById("itemsFilterForm"),
    resetBtn: document.getElementById("itemsResetBtn"),
    tableBody: document.getElementById("itemsTableBody"),
    meta: document.getElementById("itemsMeta"),
    qrStatusChip: document.getElementById("qrStatusChip"),
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
    state.filters = {
      itemCode: "",
      itemName: "",
      qrCode: "",
    };
    refs.form.reset();
    refs.pageSize.value = "10";
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

  await loadItems();

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
    refs.tableBody.innerHTML = `<tr><td class="empty" colspan="6">Loading items...</td></tr>`;
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
      refs.qrStatusChip.textContent = response.filters.qrCodeAvailable ? "QR available" : "QR not available in DB";
      refs.paginationText.textContent = buildPagerText(response.pagination);
      refs.prevBtn.disabled = response.pagination.page <= 1;
      refs.nextBtn.disabled = response.pagination.page >= response.pagination.totalPages;

      if (!response.data.length) {
        refs.tableBody.innerHTML = `<tr><td class="empty" colspan="6">No items matched the current filters.</td></tr>`;
        return;
      }

      refs.tableBody.innerHTML = response.data
        .map(
          (item) => `
            <tr>
              <td>${SKBags.escapeHtml(item.itemCode || "-")}</td>
              <td>${SKBags.escapeHtml(item.itemName)}</td>
              <td>${SKBags.escapeHtml(item.itemGroup || "-")}</td>
              <td>${SKBags.formatNumber(item.itemQuantity)}</td>
              <td>${SKBags.escapeHtml(item.qrCode || "Not available")}</td>
              <td>
                <button class="btn btn-secondary" type="button" data-add='${SKBags.escapeAttribute(
                  JSON.stringify({
                    itemCode: item.itemCode || "",
                    itemName: item.itemName || "",
                    quantity: 1,
                  }),
                )}'>Add To Draft</button>
              </td>
            </tr>
          `,
        )
        .join("");

      refs.tableBody.querySelectorAll("[data-add]").forEach((button) => {
        button.addEventListener("click", () => {
          const payload = JSON.parse(button.dataset.add);
          SKBags.addDraftItem(payload);
          syncDraftSummary();
          refs.meta.textContent = `${response.pagination.totalCount} item(s) • Added ${payload.itemCode || payload.itemName}`;
        });
      });
    } catch (error) {
      refs.meta.textContent = "Items unavailable";
      refs.qrStatusChip.textContent = "Request failed";
      refs.paginationText.textContent = "No results";
      refs.prevBtn.disabled = true;
      refs.nextBtn.disabled = true;
      refs.tableBody.innerHTML = `<tr><td class="empty" colspan="6">${SKBags.escapeHtml(error.message)}</td></tr>`;
    }
  }

  function buildPagerText(pagination) {
    if (!pagination.totalPages) {
      return "No results";
    }
    return `Page ${pagination.page} of ${pagination.totalPages} • ${pagination.totalCount} result(s)`;
  }
});
