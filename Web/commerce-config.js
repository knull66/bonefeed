# Bonefeed web commerce
# USDT (VE) or Stripe (cards). Secrets never go here — only publishable / Payment Link URLs.
# Plan: Support/STRIPE_PLAN.md
window.BONEFEED_COMMERCE = {
  // "usdt" | "stripe" | "lemonsqueezy" | "paddle"
  // Payment Links: no secret key needed on Netlify.
  provider: "stripe",

  downloadUrl: "",

  checkoutUrl: "",

  // --- Stripe Payment Links (Dashboard → Payment links) ---
  stripeProUrl: "https://buy.stripe.com/test_6oUaEXfsKe9u6KPaKt4sE00",
  stripeVipUrl: "", // paste VIP Payment Link when ready
  // Only needed if you use the Netlify function instead of Payment Links:
  // stripeCheckoutApi: "/.netlify/functions/create-checkout",
  stripePublishableKey: "", // optional pk_test_… (not required for Payment Links)

  // --- USDT manual checkout (set provider: "usdt" to use) ---
  priceUsdt: "9.99",
  priceVipUsdt: "14.99",
  usdtNetwork: "TRC20",
  usdtAddress: "TJhAMxQ57RGPuxjYo1roB4GQTiNqdFTijG",
  contactUrl: "https://t.me/vibesdistrict",
  contactLabel: "I paid — contact to unlock",

  useLemonOverlay: false,

  downloadPendingLabel: "Download soon",
  checkoutPendingLabel: "Buy Pro · Card",
};
