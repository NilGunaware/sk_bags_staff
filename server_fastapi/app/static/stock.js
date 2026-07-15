(function () {
  SKBags.initializeShell("stock");

  const refs = {
    form: document.getElementById("stockForm"),
    itemCode: document.getElementById("stockItemCode"),
    resetBtn: document.getElementById("stockResetBtn"),
    result: document.getElementById("stockResult"),
    meta: document.getElementById("stockMeta"),
  };

  refs.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    await loadStock();
  });

  refs.resetBtn.addEventListener("click", () => {
    refs.itemCode.value = "";
    refs.meta.textContent = "Ready";
    refs.result.innerHTML = `<p class="muted-copy">Enter an item code and check stock.</p>`;
    refs.itemCode.focus();
  });

  async function loadStock() {
    const lookup = refs.itemCode.value.trim();
    if (!lookup) {
      refs.result.innerHTML = `<p class="error-copy">Item code is required.</p>`;
      refs.meta.textContent = "Missing code";
      return;
    }

    refs.meta.textContent = "Loading...";
    refs.result.innerHTML = `<p class="muted-copy">Loading stock for ${SKBags.escapeHtml(lookup)}...</p>`;

    try {
      const response = await SKBags.apiRequest(`/api/items/detail/${encodeURIComponent(lookup)}`);
      refs.meta.textContent = `Loaded ${response.data.itemCode || lookup}`;
      refs.result.innerHTML = SKBags.renderItemDetail(response.data);
    } catch (error) {
      refs.meta.textContent = "Unavailable";
      refs.result.innerHTML = `<p class="error-copy">${SKBags.escapeHtml(error.message)}</p>`;
    }
  }

  loadStock();
})();
