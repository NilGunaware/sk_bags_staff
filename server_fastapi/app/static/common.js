(function () {
  const DRAFT_KEY = "skbags-order-draft-v1";

  async function apiRequest(path, options = {}) {
    const response = await fetch(path, options);
    const contentType = response.headers.get("content-type") || "";
    const isJson = contentType.includes("application/json");
    const payload = isJson ? await response.json() : await response.text();

    if (!response.ok) {
      let detail = payload?.detail ?? payload?.message ?? payload;
      if (Array.isArray(detail)) {
        detail = detail.map((item) => item.msg || JSON.stringify(item)).join(" | ");
      }
      throw new Error(typeof detail === "string" ? detail : JSON.stringify(detail));
    }

    return payload;
  }

  function buildQuery(params) {
    const query = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value === undefined || value === null) {
        return;
      }
      if (typeof value === "string" && value.trim() === "") {
        return;
      }
      query.append(key, String(value));
    });
    return query.toString();
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function escapeAttribute(value) {
    return escapeHtml(value);
  }

  function formatDate(value) {
    if (!value) {
      return "-";
    }
    return new Date(value).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
    });
  }

  function formatDateTime(value) {
    if (!value) {
      return "-";
    }
    return new Date(value).toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function formatNumber(value) {
    const number = Number(value || 0);
    return new Intl.NumberFormat("en-IN", {
      maximumFractionDigits: 2,
      minimumFractionDigits: number % 1 === 0 ? 0 : 2,
    }).format(number);
  }

  function initializeShell(pageName) {
    document.querySelectorAll("[data-nav]").forEach((link) => {
      link.classList.toggle("is-active", link.dataset.nav === pageName);
    });

    loadMeta();
    loadHealth();
    updateDraftMarkers();
  }

  async function loadMeta() {
    try {
      const meta = await apiRequest("/api/meta");
      document.querySelectorAll('[data-meta="database"]').forEach((element) => {
        element.textContent = meta.database;
      });
    } catch (_error) {
      document.querySelectorAll('[data-meta="database"]').forEach((element) => {
        element.textContent = "Database unavailable";
      });
    }
  }

  async function loadHealth() {
    try {
      await apiRequest("/health");
      document.querySelectorAll('[data-meta="health"]').forEach((element) => {
        element.textContent = "API Live";
        element.classList.add("is-live");
      });
    } catch (_error) {
      document.querySelectorAll('[data-meta="health"]').forEach((element) => {
        element.textContent = "API Down";
        element.classList.add("is-down");
      });
    }
  }

  function getDraft() {
    try {
      const raw = localStorage.getItem(DRAFT_KEY);
      const parsed = raw ? JSON.parse(raw) : [];
      return Array.isArray(parsed) ? parsed.map(normalizeDraftLine) : [];
    } catch (_error) {
      return [];
    }
  }

  function setDraft(lines) {
    localStorage.setItem(DRAFT_KEY, JSON.stringify(lines.map(normalizeDraftLine)));
    updateDraftMarkers();
  }

  function clearDraft() {
    localStorage.removeItem(DRAFT_KEY);
    updateDraftMarkers();
  }

  function addDraftItem(item) {
    const draft = getDraft();
    const normalized = normalizeDraftLine(item);
    const existing = draft.find(
      (line) =>
        (normalized.itemCode && line.itemCode === normalized.itemCode) ||
        (!normalized.itemCode && normalized.itemName && line.itemName === normalized.itemName),
    );

    if (existing) {
      existing.quantity = Number(existing.quantity || 0) + Number(normalized.quantity || 1);
    } else {
      draft.push(normalized);
    }

    setDraft(draft);
    return draft;
  }

  function normalizeDraftLine(line) {
    return {
      itemCode: String(line?.itemCode || "").trim(),
      itemName: String(line?.itemName || "").trim(),
      quantity: Number(line?.quantity || 1) > 0 ? Number(line.quantity || 1) : 1,
    };
  }

  function updateDraftMarkers() {
    const count = getDraft().length;
    document.querySelectorAll("[data-draft-count]").forEach((element) => {
      element.textContent = String(count);
    });
  }

  function setMessage(element, message, type = "") {
    element.textContent = message;
    element.className = "message-slot";
    if (type) {
      element.classList.add(`is-${type}`);
    }
  }

  function randomId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      return window.crypto.randomUUID();
    }
    return `line-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  }

  function renderItemDetail(detail) {
    const imageBlock =
      detail.image && detail.image.available && detail.image.url
        ? `
          <div class="item-detail-image-shell">
            <img
              class="item-detail-image"
              src="${escapeAttribute(detail.image.url)}"
              alt="${escapeAttribute(detail.itemName)}"
              onerror="this.style.display='none'; this.nextElementSibling.style.display='grid';"
            />
            <div class="item-detail-image item-detail-image--empty" style="display:none;">No image</div>
          </div>
        `
        : `
          <div class="item-detail-image-shell">
            <div class="item-detail-image item-detail-image--empty">No image</div>
          </div>
        `;

    const supportCodes = (detail.supportItemCodes || []).length
      ? detail.supportItemCodes.map((code) => `<span class="tag">${escapeHtml(code)}</span>`).join("")
      : `<span class="muted-copy">No extra item codes</span>`;

    const priceRows = (detail.prices || []).length
      ? detail.prices
          .map(
            (price) => `
              <tr>
                <td>${escapeHtml(price.categoryName)}</td>
                <td>${escapeHtml(price.categoryCode)}</td>
                <td>${formatNumber(price.basePrice)}</td>
                <td>${formatNumber(price.discountPercent)}%</td>
                <td>${formatNumber(price.finalPrice)}</td>
                <td>${formatDate(price.effectiveDate)}</td>
              </tr>
            `,
          )
          .join("")
      : `<tr><td class="empty" colspan="6">No price rows found for this item.</td></tr>`;

    const referencePricing = detail.referencePricing
      ? `
        <div class="detail-metric">
          <span>Ref D3</span>
          <strong>${detail.referencePricing.valueD3 == null ? "-" : formatNumber(detail.referencePricing.valueD3)}</strong>
        </div>
        <div class="detail-metric">
          <span>Ref D5</span>
          <strong>${detail.referencePricing.valueD5 == null ? "-" : formatNumber(detail.referencePricing.valueD5)}</strong>
        </div>
        <div class="detail-metric">
          <span>Ref Date</span>
          <strong>${formatDate(detail.referencePricing.effectiveDate)}</strong>
        </div>
      `
        : `
        <div class="detail-metric">
          <span>Reference Row</span>
          <strong>-</strong>
        </div>
      `;

    const branchStockRows = (detail.branchStocks || []).length
      ? detail.branchStocks
          .map(
            (branch) => `
              <tr>
                <td>${escapeHtml(branch.branchName || "-")}</td>
                <td>${escapeHtml(String(branch.branchCode ?? "-"))}</td>
                <td>${formatNumber(branch.itemQuantity || 0)}</td>
                <td>${formatNumber(branch.itemQuantityValue || 0)}</td>
              </tr>
            `,
          )
          .join("")
      : `<tr><td class="empty" colspan="4">No branch-wise stock rows found for this item.</td></tr>`;

    return `
      <article class="item-detail-card">
        <div class="item-detail-hero">
          ${imageBlock}
          <div class="item-detail-copy">
            <p class="eyebrow">Complete Item Detail</p>
            <h2>${escapeHtml(detail.itemName)}</h2>
            <p class="item-detail-subcopy">${escapeHtml(detail.itemGroup || "Ungrouped item")} • HSN ${escapeHtml(
              detail.hsnCode || "-",
            )}</p>
            <div class="tag-row">
              <span class="tag">Code ${escapeHtml(detail.itemCode || "-")}</span>
              <span class="tag">QR ${escapeHtml(detail.qrCode || "-")}</span>
              <span class="tag">Master ${escapeHtml(String(detail.itemMasterCode))}</span>
            </div>
          </div>
        </div>

        <div class="detail-metric-grid">
          <div class="detail-metric">
            <span>Stock Qty</span>
            <strong>${formatNumber(detail.itemQuantity)}</strong>
          </div>
          <div class="detail-metric">
            <span>Stock Value</span>
            <strong>${formatNumber(detail.itemQuantityValue)}</strong>
          </div>
          <div class="detail-metric">
            <span>Price Rows</span>
            <strong>${formatNumber(detail.priceCount || 0)}</strong>
          </div>
          <div class="detail-metric">
            <span>Min Final Price</span>
            <strong>${detail.minFinalPrice == null ? "-" : formatNumber(detail.minFinalPrice)}</strong>
          </div>
          <div class="detail-metric">
            <span>Max Final Price</span>
            <strong>${detail.maxFinalPrice == null ? "-" : formatNumber(detail.maxFinalPrice)}</strong>
          </div>
          ${referencePricing}
        </div>

        <div class="detail-section">
          <div class="panel-subhead">
            <p class="eyebrow">Support Codes</p>
          </div>
          <div class="tag-row">${supportCodes}</div>
        </div>

        <div class="detail-section">
          <div class="panel-subhead">
            <p class="eyebrow">BUSY Price Rows</p>
          </div>
          <div class="table-shell compact-table">
            <table>
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Code</th>
                  <th>Base Price</th>
                  <th>Discount</th>
                  <th>Final Price</th>
                  <th>Effective Date</th>
                </tr>
              </thead>
              <tbody>${priceRows}</tbody>
            </table>
          </div>
        </div>

        <div class="detail-section">
          <div class="panel-subhead">
            <p class="eyebrow">Branch Stock</p>
          </div>
          <div class="table-shell compact-table">
            <table>
              <thead>
                <tr>
                  <th>Branch</th>
                  <th>Code</th>
                  <th>Qty</th>
                  <th>Value</th>
                </tr>
              </thead>
              <tbody>${branchStockRows}</tbody>
            </table>
          </div>
        </div>
      </article>
    `;
  }

  function renderPriceCategories(categories, emptyMessage = "No price categories found.") {
    if (!Array.isArray(categories) || !categories.length) {
      return `<p class="muted-copy">${escapeHtml(emptyMessage)}</p>`;
    }

    const rows = categories
      .map(
        (category) => `
          <tr>
            <td>${escapeHtml(category.categoryName || `${category.categoryCode} Price`)}</td>
            <td>${escapeHtml(category.categoryCode || "-")}</td>
            <td>${escapeHtml(String(category.slotId ?? "-"))}</td>
            <td>${formatNumber(category.itemCount || 0)}</td>
            <td>${formatNumber(category.accountCount || 0)}</td>
            <td>${formatNumber(category.discountedItemCount || 0)}</td>
            <td>${formatPriceRange(category.minFinalPrice, category.maxFinalPrice)}</td>
          </tr>
        `,
      )
      .join("");

    return `
      <div class="table-shell compact-table">
        <table>
          <thead>
            <tr>
              <th>Category</th>
              <th>Code</th>
              <th>Slot</th>
              <th>Items</th>
              <th>Accounts</th>
              <th>Discounted</th>
              <th>Final Price Range</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      </div>
    `;
  }

  function formatPriceRange(minFinalPrice, maxFinalPrice) {
    if (minFinalPrice == null && maxFinalPrice == null) {
      return "-";
    }
    if (minFinalPrice == null) {
      return formatNumber(maxFinalPrice);
    }
    if (maxFinalPrice == null) {
      return formatNumber(minFinalPrice);
    }
    if (Number(minFinalPrice) === Number(maxFinalPrice)) {
      return formatNumber(minFinalPrice);
    }
    return `${formatNumber(minFinalPrice)} - ${formatNumber(maxFinalPrice)}`;
  }

  window.SKBags = {
    apiRequest,
    buildQuery,
    escapeAttribute,
    escapeHtml,
    formatDate,
    formatDateTime,
    formatNumber,
    formatPriceRange,
    initializeShell,
    getDraft,
    setDraft,
    clearDraft,
    addDraftItem,
    normalizeDraftLine,
    renderPriceCategories,
    renderItemDetail,
    setMessage,
    randomId,
  };
})();
