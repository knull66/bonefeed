/**
 * Optional Stripe Checkout Session (Netlify Function).
 * Set env STRIPE_SECRET_KEY in Netlify (never commit sk_ keys).
 *
 * POST JSON: { "tier": "pro" | "vip" }
 * Returns: { "url": "https://checkout.stripe.com/..." }
 */
const Stripe = require("stripe");

const PRICES = {
  // Prefer Price IDs from Dashboard (price_xxx). Fallback amounts in cents for test.
  pro: process.env.STRIPE_PRICE_PRO || null,
  vip: process.env.STRIPE_PRICE_VIP || null,
};

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return { statusCode: 405, body: "Method Not Allowed" };
  }

  const secret = process.env.STRIPE_SECRET_KEY;
  if (!secret) {
    return {
      statusCode: 500,
      body: JSON.stringify({ error: "STRIPE_SECRET_KEY not configured" }),
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
