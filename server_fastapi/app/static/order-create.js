document.addEventListener("DOMContentLoaded", () => {
  SKBags.initializeShell("create-order");

  const refs = {
    form: document.getElementById("createOrderForm"),
    orderDate: document.getElementById("createOrderDate"),
    seriesCode: document.getElementById("createSeriesCode"),
    partyName: document.getElementById("createPartyName"),
    lines: document.getElementById("orderLines"),
    message: document.getElementById("createOrderMessage"),
    addLineBtn: document.getElementById("addLineBtn"),
    resetFormBtn: document.getElementById("resetFormBtn"),
    clearDraftBtn: document.getElementById("clearDraftBtn"),
    loadDraftBtn: document.getElementById("loadDraftBtn"),
    draftChip: document.getElementById("draftChip"),
  };

  const state = {
    lines: [],
  };

  refs.orderDate.value = new Date().toISOString().slice(0, 10);
  loadDraftOrBlank();

  refs.addLineBtn.addEventListener("click", () => {
    state.lines.push(createLine());
    renderLines();
  });

  refs.resetFormBtn.addEventListener("click", () => {
    resetForm();
  });

  refs.clearDraftBtn.addEventListener("click", () => {
    SKBags.clearDraft();
    syncDraftBadge();
  });

  refs.loadDraftBtn.addEventListener("click", () => {
    loadDraftOrBlank();
    SKBags.setMessage(refs.message, "Draft loaded into the form.", "success");
  });

  refs.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    await submitOrder();
  });

  function createLine(line = {}) {
    return {
      id: SKBags.randomId(),
      itemCode: line.itemCode || "",
      itemName: line.itemName || "",
      quantity: line.quantity || 1,
    };
  }

  function resetForm() {
    refs.form.reset();
    refs.orderDate.value = new Date().toISOString().slice(0, 10);
    loadDraftOrBlank();
    SKBags.setMessage(refs.message, "", "");
  }

  function loadDraftOrBlank() {
    const draft = SKBags.getDraft();
    state.lines = draft.length ? draft.map((line) => createLine(line)) : [createLine()];
    renderLines();
    syncDraftBadge();
  }

  function syncDraftBadge() {
    refs.draftChip.textContent = `Draft ${SKBags.getDraft().length}`;
  }

  function renderLines() {
    refs.lines.innerHTML = state.lines
      .map(
        (line) => `
          <div class="line-row">
            <label>
              <span>Item Code</span>
              <input type="text" value="${SKBags.escapeAttribute(line.itemCode)}" data-line-id="${line.id}" data-field="itemCode" placeholder="44593" />
            </label>
            <label>
              <span>Item Name</span>
              <input type="text" value="${SKBags.escapeAttribute(line.itemName)}" data-line-id="${line.id}" data-field="itemName" placeholder="Optional fallback item name" />
            </label>
            <label>
              <span>Quantity</span>
              <input type="number" min="0.01" step="0.01" value="${SKBags.escapeAttribute(String(line.quantity))}" data-line-id="${line.id}" data-field="quantity" />
            </label>
            <button class="btn btn-secondary" type="button" data-remove-id="${line.id}">Remove</button>
          </div>
        `,
      )
      .join("");

    refs.lines.querySelectorAll("[data-field]").forEach((input) => {
      input.addEventListener("input", () => {
        const line = state.lines.find((entry) => entry.id === input.dataset.lineId);
        if (!line) {
          return;
        }
        if (input.dataset.field === "quantity") {
          line.quantity = Number(input.value || 0);
        } else {
          line[input.dataset.field] = input.value;
        }
      });
    });

    refs.lines.querySelectorAll("[data-remove-id]").forEach((button) => {
      button.addEventListener("click", () => {
        state.lines = state.lines.filter((line) => line.id !== button.dataset.removeId);
        if (!state.lines.length) {
          state.lines = [createLine()];
        }
        renderLines();
      });
    });
  }

  async function submitOrder() {
    try {
      const items = state.lines
        .map((line) => ({
          itemCode: String(line.itemCode || "").trim(),
          itemName: String(line.itemName || "").trim(),
          quantity: Number(line.quantity || 0),
        }))
        .filter((line) => (line.itemCode || line.itemName) && line.quantity > 0);

      if (!refs.partyName.value.trim()) {
        throw new Error("Party name is required.");
      }

      if (!items.length) {
        throw new Error("Add at least one valid item line.");
      }

      const response = await SKBags.apiRequest("/api/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          orderDate: refs.orderDate.value || null,
          seriesCode: refs.seriesCode.value.trim() || null,
          partyName: refs.partyName.value.trim(),
          items,
        }),
      });

      SKBags.clearDraft();
      syncDraftBadge();
      state.lines = [createLine()];
      refs.form.reset();
      refs.orderDate.value = new Date().toISOString().slice(0, 10);
      renderLines();

      refs.message.innerHTML = `Created <a class="inline-link" href="/orders/${response.data.id}">${SKBags.escapeHtml(
        response.data.orderNo,
      )}</a> successfully.`;
      refs.message.className = "message-slot is-success";
    } catch (error) {
      SKBags.setMessage(refs.message, error.message, "error");
    }
  }
});
