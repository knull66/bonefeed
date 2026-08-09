// Bonefeed web commerce — USDT manual (no company / no Stripe required)
// Step-by-step: Support/PAY_USDT.md
window.BONEFEED_COMMERCE = {
  // "usdt" | "lemonsqueezy" | "paddle" | "stripe"
  provider: "usdt",

  // Public HTTPS URL to the notarized DMG (leave empty until hosted)
  downloadUrl: "",

  // Ignored when provider is "usdt" (modal is used instead)
  checkoutUrl: "",

  // --- USDT manual checkout ---
  priceUsdt: "9.99",
  // Must match the deposit network in Binance/OKX (TRC20 recommended)
  usdtNetwork: "TRC20",
  // Paste your Binance/OKX deposit address here (TRC20 starts with T…)
  usdtAddress: "TJhAMxQ57RGPuxjYo1roB4GQTiNqdFTijG",
  // Where buyers message you after paying (Telegram / mailto / WhatsApp link)
  contactUrl: "https://t.me/vibesdistrict",
  contactLabel: "I paid — contact to unlock",

  useLemonOverlay: false,

  downloadPendingLabel: "Download soon",
  checkoutPendingLabel: "Buy Pro · USDT",
};
