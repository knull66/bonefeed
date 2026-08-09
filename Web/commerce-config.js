// Bonefeed web commerce — fill these after Lemon Squeezy + notarized DMG are ready.
// See Support/SHIP_WEB.md
window.BONEFEED_COMMERCE = {
  // "lemonsqueezy" | "paddle"
  provider: "lemonsqueezy",

  // Public HTTPS URL to the notarized DMG (GitHub Release, R2, etc.)
  // Leave empty until the DMG is hosted — Download stays disabled.
  downloadUrl: "",

  // Lemon Squeezy or Paddle checkout / pay link for Bonefeed Pro ($9.99)
  // Leave empty until the store product exists — Buy Pro stays disabled.
  checkoutUrl: "",

  // true = open Lemon.js overlay when provider is lemonsqueezy
  useLemonOverlay: true,

  // Shown on buttons while URLs are empty
  downloadPendingLabel: "Download soon",
  checkoutPendingLabel: "Checkout soon",
};
