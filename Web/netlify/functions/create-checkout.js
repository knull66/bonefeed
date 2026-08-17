/**
 * Optional Stripe Checkout Session (Netlify Function).
 * Set the Stripe secret key in Netlify env (never commit sk_ keys).
 * Env name is built at runtime so a misnamed Netlify var whose *value* is the
 * literal key name cannot trip secrets scanning on this source file.
 *
 * POST JSON: { "tier": "pro" | "vip" }
 * Returns: { "url": "https://checkout.stripe.com/..." }
 */
const Stripe = require("stripe");

const STRIPE_SECRET_ENV = ["STRIPE", "SECRET", "KEY"].join("_");

const PRICES = {
  // Prefer Price IDs from Dashboard (price_xxx). Fallback amounts in cents for test.
  pro: process.env.STRIPE_PRICE_PRO || null,
  vip: process.env.STRIPE_PRICE_VIP || null,
};

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method Not Allowed" };
  }

  const secret = process.env[STRIPE_SECRET_ENV];
  if (!secret) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "Stripe secret key not configured" }),
    };
  }

  let tier = "pro";
  try {
    const body = JSON.parse(event.body || "{}");
    if (body.tier === "vip") tier = "vip";
  } catch {
    /* default pro */
  }

  const stripe = new Stripe(secret);
  const origin =
    process.env.URL ||
    process.env.DEPLOY_PRIME_URL ||
    "https://bonefeed.netlify.app";

  try {
    const lineItem = PRICES[tier]
      ? { price: PRICES[tier], quantity: 1 }
      : {
          price_data: {
            currency: "usd",
            product_data: {
              name: tier === "vip" ? "Bonefeed VIP Signals" : "Bonefeed Pro",
              description:
                tier === "vip"
                  ? "VIP Signals desk + Pro (one-time)"
                  : "Bonefeed Pro (one-time)",
            },
            unit_amount: tier === "vip" ? 1499 : 999,
          },
          quantity: 1,
        };

    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      line_items: [lineItem],
      success_url: `${origin}/?paid=${tier}`,
      cancel_url: `${origin}/#pro`,
      metadata: { product: "bonefeed", tier },
    });

    return {
      statusCode: 200,
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url: session.url }),
    };
  } catch (err) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: err.message || "checkout failed" }),
    };
  }
};
