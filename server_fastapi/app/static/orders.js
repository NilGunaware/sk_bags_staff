document.addEventListener("DOMContentLoaded", async () => {
  SKBags.initializeShell("orders");

  const refs = {
    form: document.getElementById("ordersFilterForm"),
    resetBtn: document.getElementById("resetFiltersBtn"),
    tableBody: document.getElementById("ordersTableBody"),
    meta: document.getElementById("ordersMeta"),
    countChip: document.getElementById("ordersCountChip"),
    paginationText: document.getElementById("paginationText"),
    prevBtn: document.getElementById("prevPageBtn"),
    nextBtn: document.getElementById("nextPageBtn"),
    orderNo: document.getElementById("orderNo"),
    seriesCode: document.getElementById("seriesCode"),
    partyName: document.getElementById("partyName"),
    itemCode: document.getElementById("itemCode"),
    itemName: document.getElementById("itemName"),
    fromDate: document.getElementById("fromDate"),
    toDate: document.getElementById("toDate"),
    pageSize: document.getElementById("pageSize"),
  };

  const state = {
    page: 1,
    pageSize: 10,
    filters: {
      orderNo: "",
      seriesCode: "",
      partyName: "",
      itemCode: "",
      itemName: "",
      fromDate: "",
      toDate: "",
    },
    pagination: null,
  };

  refs.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    syncFilters();
    state.page = 1;
    await loadOrders();
  });

  refs.resetBtn.addEventListener("click", async () => {
    state.page = 1;
    state.pageSize = 10;
    state.filters = {
      orderNo: "",
      seriesCode: "",
      partyName: "",
      itemCode: "",
      itemName: "",
      fromDate: "",
      toDate: "",
    };
    refs.form.reset();
    refs.pageSize.value = "10";
    await loadOrders();
  });

  refs.prevBtn.addEventListener("click", async () => {
    if (state.page > 1) {
      state.page -= 1;
      await loadOrders();
    }
  });

  refs.nextBtn.addEventListener("click", async () => {
    if (state.pagination && state.page < state.pagination.totalPages) {
      state.page += 1;
      await loadOrders();
    }
  });

  await loadOrders();

  function syncFilters() {
    state.pageSize = Number(refs.pageSize.value || 10);
    state.filters = {
      orderNo: refs.orderNo.value.trim(),
      seriesCode: refs.seriesCode.value.trim(),
      partyName: refs.partyName.value.trim(),
      itemCode: refs.itemCode.value.trim(),
      itemName: refs.itemName.value.trim(),
      fromDate: refs.fromDate.value,
      toDate: refs.toDate.value,
    };
  }

  async function loadOrders() {
    refs.tableBody.innerHTML = `<tr><td class="empty" colspan="7">Loading orders...</td></tr>`;
    refs.meta.textContent = "Loading...";
    refs.countChip.textContent = "Waiting...";

    try {
      const query = SKBags.buildQuery({
        page: state.page,
        pageSize: state.pageSize,
        ...state.filters,
      });
      const response = await SKBags.apiRequest(`/api/orders?${query}`);
      state.pagination = response.pagination;

      refs.meta.textContent = "Filters applied safely";
      refs.countChip.textContent = `${response.pagination.totalCount} order(s)`;
      refs.paginationText.textContent = buildPagerText(response.pagination);
      refs.prevBtn.disabled = response.pagination.page <= 1;
      refs.nextBtn.disabled = response.pagination.page >= response.pagination.totalPages;

      if (!response.data.length) {
        refs.tableBody.innerHTML = `<tr><td class="empty" colspan="7">No orders matched the current filters.</td></tr>`;
        return;
      }

      refs.tableBody.innerHTML = response.data
        .map(
          (order) => `
            <tr>
              <td>${SKBags.escapeHtml(order.orderNo)}</td>
              <td>${SKBags.formatDate(order.orderDate)}</td>
              <td>${SKBags.escapeHtml(order.seriesCode || "-")}</td>
              <td>${SKBags.escapeHtml(order.partyName)}</td>
              <td>${SKBags.escapeHtml(String(order.totalItems))}</td>
              <td>${SKBags.formatNumber(order.totalQuantity)}</td>
              <td>
                <a class="btn btn-secondary" href="/orders/${order.id}">Open Detail</a>
              </td>
            </tr>
          `,
        )
        .join("");
    } catch (error) {
      refs.meta.textContent = "Orders unavailable";
      refs.countChip.textContent = "Request failed";
      refs.paginationText.textContent = "No results";
      refs.prevBtn.disabled = true;
      refs.nextBtn.disabled = true;
      refs.tableBody.innerHTML = `<tr><td class="empty" colspan="7">${SKBags.escapeHtml(error.message)}</td></tr>`;
    }
  }

  function buildPagerText(pagination) {
    if (!pagination.totalPages) {
      return "No results";
    }
    return `Page ${pagination.page} of ${pagination.totalPages} • ${pagination.totalCount} result(s)`;
  }
});
