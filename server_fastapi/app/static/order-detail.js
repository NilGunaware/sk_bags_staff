document.addEventListener("DOMContentLoaded", async () => {
  SKBags.initializeShell("orders");

  const orderId = Number(window.location.pathname.split("/").filter(Boolean).pop());
  const refs = {
    heroTitle: document.getElementById("detailHeroTitle"),
    heroText: document.getElementById("detailHeroText"),
    summary: document.getElementById("detailSummary"),
    form: document.getElementById("detailFilterForm"),
    resetBtn: document.getElementById("detailResetBtn"),
    itemCode: document.getElementById("detailItemCode"),
    itemName: document.getElementById("detailItemName"),
    pageSize: document.getElementById("detailPageSize"),
    meta: document.getElementById("detailMeta"),
    rawApiLink: document.getElementById("rawApiLink"),
    tableBody: document.getElementById("detailTableBody"),
    paginationText: document.getElementById("detailPaginationText"),
    prevBtn: document.getElementById("detailPrevBtn"),
    nextBtn: document.getElementById("detailNextBtn"),
  };

  const state = {
    page: 1,
    pageSize: 10,
    filters: {
      itemCode: "",
      itemName: "",
    },
    pagination: null,
  };

  refs.rawApiLink.href = `/api/orders/${orderId}`;

  refs.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    syncFilters();
    state.page = 1;
    await loadDetail();
  });

  refs.resetBtn.addEventListener("click", async () => {
    state.page = 1;
    state.pageSize = 10;
    state.filters = { itemCode: "", itemName: "" };
    refs.form.reset();
    refs.pageSize.value = "10";
    await loadDetail();
  });

  refs.prevBtn.addEventListener("click", async () => {
    if (state.page > 1) {
      state.page -= 1;
      await loadDetail();
    }
  });

  refs.nextBtn.addEventListener("click", async () => {
    if (state.pagination && state.page < state.pagination.totalPages) {
      state.page += 1;
      await loadDetail();
    }
  });

  await loadDetail();

  function syncFilters() {
    state.pageSize = Number(refs.pageSize.value || 10);
    state.filters = {
      itemCode: refs.itemCode.value.trim(),
      itemName: refs.itemName.value.trim(),
    };
  }

  async function loadDetail() {
    refs.meta.textContent = "Loading...";
    refs.tableBody.innerHTML = `<tr><td class="empty" colspan="5">Loading order detail...</td></tr>`;

    try {
      const query = SKBags.buildQuery({
        itemPage: state.page,
        itemPageSize: state.pageSize,
        ...state.filters,
      });
      const response = await SKBags.apiRequest(`/api/orders/${orderId}?${query}`);
      const order = response.data;
      state.pagination = response.itemPagination;

      refs.heroTitle.textContent = `${order.orderNo} • ${order.partyName}`;
      refs.heroText.textContent = `Series ${order.seriesCode || "-"} • ${SKBags.formatDate(order.orderDate)} • ${SKBags.formatNumber(order.totalQuantity)} total quantity`;
      refs.meta.textContent = `${order.itemTotalCount} line(s)`;
      refs.paginationText.textContent = buildPagerText(response.itemPagination);
      refs.prevBtn.disabled = response.itemPagination.page <= 1;
      refs.nextBtn.disabled = response.itemPagination.page >= response.itemPagination.totalPages;

      refs.summary.innerHTML = `
        <article class="stat-card">
          <span>Order No</span>
          <strong>${SKBags.escapeHtml(order.orderNo)}</strong>
          <small>API order id ${order.id}</small>
        </article>
        <article class="stat-card">
          <span>Order Date</span>
          <strong>${SKBags.formatDate(order.orderDate)}</strong>
          <small>Series ${SKBags.escapeHtml(order.seriesCode || "-")}</small>
        </article>
        <article class="stat-card">
          <span>Party</span>
          <strong>${SKBags.escapeHtml(order.partyName)}</strong>
          <small>Master code ${SKBags.escapeHtml(String(order.partyMasterCode ?? "-"))}</small>
        </article>
        <article class="stat-card">
          <span>Total Quantity</span>
          <strong>${SKBags.formatNumber(order.totalQuantity)}</strong>
          <small>${SKBags.escapeHtml(String(order.totalItems))} item(s)</small>
        </article>
      `;

      if (!order.items.length) {
        refs.tableBody.innerHTML = `<tr><td class="empty" colspan="5">No line items matched the current filters.</td></tr>`;
        return;
      }

      refs.tableBody.innerHTML = order.items
        .map(
          (item) => `
            <tr>
              <td>${SKBags.escapeHtml(String(item.lineNo))}</td>
              <td>${SKBags.escapeHtml(item.itemCode || "-")}</td>
              <td>${SKBags.escapeHtml(item.itemName)}</td>
              <td>${SKBags.formatNumber(item.quantity)}</td>
              <td>${SKBags.formatDateTime(item.createdAt)}</td>
            </tr>
          `,
        )
        .join("");
    } catch (error) {
      refs.meta.textContent = "Order unavailable";
      refs.paginationText.textContent = "No results";
      refs.prevBtn.disabled = true;
      refs.nextBtn.disabled = true;
      refs.heroTitle.textContent = "Order not available";
      refs.heroText.textContent = error.message;
      refs.summary.innerHTML = `
        <article class="stat-card">
          <span>Status</span>
          <strong>Unavailable</strong>
          <small>${SKBags.escapeHtml(error.message)}</small>
        </article>
      `;
      refs.tableBody.innerHTML = `<tr><td class="empty" colspan="5">${SKBags.escapeHtml(error.message)}</td></tr>`;
    }
  }

  function buildPagerText(pagination) {
    if (!pagination.totalPages) {
      return "No results";
    }
    return `Page ${pagination.page} of ${pagination.totalPages} • ${pagination.totalCount} result(s)`;
  }
});
