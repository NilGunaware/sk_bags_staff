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

  window.SKBags = {
    apiRequest,
    buildQuery,
    escapeAttribute,
    escapeHtml,
    formatDate,
    formatDateTime,
    formatNumber,
    initializeShell,
    getDraft,
    setDraft,
    clearDraft,
    addDraftItem,
    normalizeDraftLine,
    setMessage,
    randomId,
  };
})();
