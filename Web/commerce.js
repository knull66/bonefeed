(() => {
  const cfg = window.BONEFEED_COMMERCE || {};
  const downloadUrl = (cfg.downloadUrl || "").trim();
  const checkoutUrl = (cfg.checkoutUrl || "").trim();

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

  const openCheckout = (e) => {
    if (!checkoutUrl) {
      e.preventDefault();
      return;
    }
    if (
      cfg.provider === "lemonsqueezy" &&
      cfg.useLemonOverlay &&
      window.LemonSqueezy?.Url?.Open
    ) {
      e.preventDefault();
      window.LemonSqueezy.Url.Open(checkoutUrl);
      return;
    }
    // Default: navigate / new tab
  };

  const wireCheckout = (el) => {
    if (!el) return;
    if (!checkoutUrl) {
      el.classList.add("is-pending");
      el.setAttribute("aria-disabled", "true");
      el.addEventListener("click", (e) => e.preventDefault());
      if (el.dataset.pendingLabel || cfg.checkoutPendingLabel) {
        el.textContent = el.dataset.pendingLabel || cfg.checkoutPendingLabel;
      }
      return;
    }
    el.href = checkoutUrl;
    el.target = "_blank";
    el.rel = "noopener noreferrer";
    el.removeAttribute("aria-disabled");
    el.classList.remove("is-pending");
    el.addEventListener("click", openCheckout);
  };

  document.querySelectorAll("[data-download]").forEach(wireDownload);
  document.querySelectorAll("[data-checkout]").forEach(wireCheckout);

  const status = document.querySelector("[data-commerce-status]");
  if (status) {
    if (downloadUrl && checkoutUrl) {
      status.textContent = "Free DMG + Pro checkout live.";
    } else if (downloadUrl) {
      status.textContent = "Free download live · Pro checkout coming next.";
    } else if (checkoutUrl) {
      status.textContent = "Pro checkout ready · Free DMG hosting pending.";
    } else {
      status.textContent =
        "Checkout + DMG links pending — see Support/SHIP_WEB.md";
    }
  }
})();
