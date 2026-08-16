# Stripe — Vibes District + Bonefeed

**Business:** [vibesdistrict.pro](https://www.vibesdistrict.pro) — photography, apps & websites  
**Products needed:** Payments · Invoicing  
**Bonefeed today:** USDT manual checkout on Netlify; Stripe is the card path for markets that can pay with Visa/MC.

---

## 0) Security (do this first)

You pasted a **Secret key (`sk_test_…`) in chat**. Treat it as leaked:

1. Stripe Dashboard → Developers → API keys → **Roll / delete** that secret key  
2. Create a new test secret key  
3. **Never** put `sk_` in git, `commerce-config.js`, or chat  
4. Store secrets only in Netlify / local `.env` (already gitignored)

Publishable `pk_test_…` can live in the frontend. Secret must not.

---

## 1) Connect Stripe MCP in Cursor (so the agent can use `stripe_implementation_planner`)

This session **does not** have the Stripe plugin/MCP loaded yet. Do this once:

### Option A — Cursor Settings UI
1. Cursor Settings → **MCP**  
2. Add server URL: `https://mcp.stripe.com`  
3. Authenticate with Stripe (OAuth) when prompted  
4. **New chat** and ask again — tools like `stripe_implementation_planner` should appear  

### Option B — `~/.cursor/mcp.json`
```json
{
  "mcpServers": {
    "stripe": {
      "url": "https://mcp.stripe.com"
    }
  }
}
```
Restart Cursor / reload MCP, then OAuth.

Docs: https://docs.stripe.com/mcp

Until MCP is connected, use this plan + Dashboard Payment Links / Invoices.

---

## 2) Integration plan (best practice for your use case)

### A. Vibes District studio (photos / websites / apps)
| Need | Stripe product | How |
|------|----------------|-----|
| One-off client payments | **Payment Links** or **Checkout** | Link in proposal / WhatsApp / site |
| Formal bills (brand, tax line, PDF) | **Invoicing** | Dashboard → Customers → Invoice → Send |
| Retainers / monthly | **Billing** (later) | Subscriptions when you have recurring clients |

**Recommended start (this week):**
1. Enable **Invoicing** in Stripe Dashboard  
2. Create 2–3 **Payment Links**: e.g. “Deposit 50%”, “Website package”, “Photo session”  
3. Put links on vibesdistrict.pro / send from Telegram  
4. Use **Invoices** when the client needs a PDF / company details  

No code required for studio invoicing.

### B. Bonefeed (mac app: Pro $9.99 / VIP $14.99)
| Path | Pros | Cons |
|------|------|------|
| Keep **USDT** | Works in VE | Manual unlock |
| Add **Stripe Checkout** | Cards, auto receipt | Needs Stripe available in buyer’s country; Netlify function + webhook |
| **Payment Links** | Fastest Stripe path | Fixed prices; unlock still semi-manual until webhook |

**Recommended Bonefeed phase 1:** Payment Links for Pro + VIP (test mode) → paste URLs in `Web/commerce-config.js` → switch `provider` to `stripe`.  
**Phase 2:** Netlify function `create-checkout` + webhook → Telegram notify / unlock codes.

---

## Netlify env vars (solo si usas la function `create-checkout`)

Con **Payment Links** (como el link que ya tienes) **NO hace falta** poner la Secret key en Netlify.
Solo despliega el site con `stripeProUrl` / `stripeVipUrl` en `commerce-config.js`.

Si más adelante activas `stripeCheckoutApi`, entonces:

1. [app.netlify.com](https://app.netlify.com) → tu site **bonefeed** (o el que uses)
2. **Site configuration** → **Environment variables** → **Add a variable** / **Add environment variables**
3. Scope: **All scopes** (o Production + Deploy Previews)
4. Añade:

| Key | Value | Notas |
|-----|--------|--------|
| `STRIPE_SECRET_KEY` | `sk_test_…` (la **nueva** tras el roll) | Solo aquí, nunca en chat/git |
| `STRIPE_PRICE_PRO` | `price_…` (opcional) | Price ID del producto Pro |
| `STRIPE_PRICE_VIP` | `price_…` (opcional) | Price ID VIP |

5. **Save** → **Deploys** → **Trigger deploy** → **Deploy site** (las env vars no aplican al deploy anterior)

Publishable `pk_test_…` **no** es obligatoria con Payment Links. Si la pones, puede ir en `commerce-config.js` (`stripePublishableKey`) porque es pública.

---

## 3) Bonefeed wiring (repo)

Files:
- `Web/commerce-config.js` — `provider: "stripe"` + Payment Link URLs  
- `Web/commerce.js` — already opens `checkoutUrl`; extended for per-tier Stripe links  
- `Web/netlify/functions/create-checkout.js` — optional dynamic Checkout (uses `STRIPE_SECRET_KEY` env)  
- Netlify env: `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `URL`

### Dashboard (test mode)
1. Products → Add **Bonefeed Pro** ($9.99 one-time) and **Bonefeed VIP** ($14.99 one-time)  
2. Payment link for each → copy URLs  
3. Paste into `commerce-config.js` as `stripeProUrl` / `stripeVipUrl`  
4. Set `provider: "stripe"`  
5. Deploy Netlify  

### Live mode later
Switch to `pk_live_` / `sk_live_` in Netlify only after test payments succeed. Keep USDT as fallback for VE (`provider: "usdt"`).

---

## 4) Invoicing checklist (studio)

- [ ] Business address + logo in Stripe → Settings → Business  
- [ ] Tax / VAT if needed  
- [ ] Customer email required on invoices  
- [ ] Payment methods: Cards (+ Link)  
- [ ] Brand color matching vibesdistrict.pro  

---

## 5) What “done” looks like

1. Test card `4242…` pays Bonefeed Pro via Stripe Checkout / Payment Link  
2. You receive email + Dashboard payment  
3. You unlock Pro (manual until webhook)  
4. Studio invoice PDF sends and collects payment  
5. Secret keys never appear in git  

---

## Next step in chat

After you connect Stripe MCP (step 1) **and rotate the leaked secret**, say:  
“MCP listo — crea productos y Payment Links”  
and we can drive Dashboard actions via tools (or finish the Netlify Checkout function with your **new** secret in Netlify env only).
