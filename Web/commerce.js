(() => {
  const cfg = window.BONEFEED_COMMERCE || {};
  const downloadUrl = (cfg.downloadUrl || "").trim();
  const checkoutUrl = (cfg.checkoutUrl || "").trim();
  const usdtAddress = (cfg.usdtAddress || "").trim();
  const contactUrl = (cfg.contactUrl || "").trim();
  const provider = (cfg.provider || "usdt").toLowerCase();
  const isUsdt = provider === "usdt";

  const wireDownload = (el) => {
    if (!el) return;
    if (!downloadUrl) {
      el.classList.add("is-pending");
      el.setAttribute("aria-disabled", "true");
      el.addEventListener("click", (e) => e.preventDefault());
      if (el.dataset.pendingLabel || cfg.downloadPendingLabel) {
        el.textContent = el.dataset.pendingLabel || cfg.downloadPendingLabel;
      }
      return;
    }
    el.href = downloadUrl;
    el.removeAttribute("aria-disabled");
    el.classList.remove("is-pending");
  };

  const openUsdtModal = (e) => {
    e.preventDefault();
    const modal = document.getElementById("pay-modal");
    if (!modal) return;
    if (modal.parentElement !== document.body) {
      document.body.appendChild(modal);
    }
    modal.hidden = false;
    document.body.classList.add("pay-open");
    modal.scrollTop = 0;
    requestAnimationFrame(() => {
      modal.scrollTop = 0;
      modal.querySelector(".pay-sheet")?.scrollIntoView({ block: "start", inline: "nearest" });
    });
    modal.querySelector(".pay-close")?.focus({ preventScroll: true });
  };

  const closeUsdtModal = () => {
    const modal = document.getElementById("pay-modal");
    if (!modal) return;
    modal.hidden = true;
    document.body.classList.remove("pay-open");
  };

  const openCheckout = (e) => {
    if (isUsdt) {
      openUsdtModal(e);
      return;
    }
    if (!checkoutUrl) {
      e.preventDefault();
      return;
    }
    if (
      provider === "lemonsqueezy" &&
      cfg.useLemonOverlay &&
      window.LemonSqueezy?.Url?.Open
    ) {
      e.preventDefault();
      window.LemonSqueezy.Url.Open(checkoutUrl);
    }
  };

  const wireCheckout = (el) => {
    if (!el) return;
    const ready = isUsdt ? Boolean(usdtAddress) : Boolean(checkoutUrl);
    if (!ready) {
      el.classList.add("is-pending");
      el.setAttribute("aria-disabled", "true");
      el.addEventListener("click", (e) => e.preventDefault());
      const pending = isUsdt
        ? "Add USDT address"
        : el.dataset.pendingLabel || cfg.checkoutPendingLabel;
      el.textContent = pending;
      return;
    }

    el.href = isUsdt ? "#pay" : checkoutUrl;
    if (!isUsdt) {
      el.target = "_blank";
      el.rel = "noopener noreferrer";
    } else {
      el.removeAttribute("target");
    }
    el.removeAttribute("aria-disabled");
    el.classList.remove("is-pending");
    el.textContent = el.dataset.liveLabel || "Buy Pro · USDT";
    el.addEventListener("click", openCheckout);
  };

  // Fill modal fields
  const amountEl = document.querySelector("[data-pay-amount]");
  const networkEl = document.querySelector("[data-pay-network]");
  const addressEl = document.querySelector("[data-pay-address]");
  const contactEl = document.querySelector("[data-pay-contact]");
  const copyBtn = document.querySelector("[data-copy-address]");

  if (amountEl) amountEl.textContent = `${cfg.priceUsdt || "9.99"} USDT`;
  if (networkEl) networkEl.textContent = cfg.usdtNetwork || "TRC20";
  if (addressEl) {
    addressEl.textContent = usdtAddress || "Paste usdtAddress in commerce-config.js";
  }
  if (contactEl) {
    if (contactUrl) {
      contactEl.href = contactUrl;
      contactEl.textContent = cfg.contactLabel || "I paid — contact to unlock";
      contactEl.classList.remove("is-pending");
    } else {
      contactEl.href = "#";
      contactEl.textContent = "Set contactUrl in commerce-config.js";
      contactEl.classList.add("is-pending");
      contactEl.addEventListener("click", (e) => e.preventDefault());
    }
  }

  copyBtn?.addEventListener("click", async () => {
    if (!usdtAddress) return;
    try {
      await navigator.clipboard.writeText(usdtAddress);
      copyBtn.textContent = "Copied";
      window.setTimeout(() => {
        copyBtn.textContent = "Copy address";
      }, 1600);
    } catch {
      copyBtn.textContent = "Select & copy manually";
    }
  });

  document.querySelectorAll("[data-close-pay]").forEach((el) => {
    el.addEventListener("click", (e) => {
      e.preventDefault();
      closeUsdtModal();
    });
  });

  // Tap dimmed area (outside sheet) closes modal
  document.getElementById("pay-modal")?.addEventListener("click", (e) => {
    if (e.target?.id === "pay-modal") closeUsdtModal();
  });

  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeUsdtModal();
  });

  document.querySelectorAll("[data-download]").forEach(wireDownload);
  document.querySelectorAll("[data-checkout]").forEach(wireCheckout);

  const status = document.querySelector("[data-commerce-status]");
  if (status) {
    if (isUsdt && usdtAddress && downloadUrl) {
      status.textContent = "Free DMG + USDT Pro checkout live.";
    } else if (isUsdt && usdtAddress) {
      status.textContent =
        "USDT Pro ready · paste DMG URL when notarized (downloadUrl).";
    } else if (isUsdt) {
      status.textContent =
        "Next: paste usdtAddress + contactUrl in commerce-config.js — Support/PAY_USDT.md";
    } else if (downloadUrl && checkoutUrl) {
      status.textContent = "Free DMG + Pro checkout live.";
    } else {
      status.textContent = "Checkout + DMG links pending — see Support/PAY_USDT.md";
    }
  }
})();
