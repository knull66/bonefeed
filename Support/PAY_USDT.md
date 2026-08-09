# Bonefeed Pro — cobrar con USDT (sin empresa / sin Binance Pay Merchant)

Guía paso a paso para Venezuela u otros países donde Stripe / Lemon / Merchant KYB no aplican.

---

## Paso 1 — Elige red (hazlo una vez)

Recomendado para fees bajos: **USDT · TRC20 (Tron)**.

Alternativa si tus compradores viven en BNB Chain: **USDT · BEP20**.

**Usa solo UNA red en la web.** Si mezclas TRC20/BEP20, pierdes fondos.

---

## Paso 2 — Saca tu address en Binance

1. Abre la app / web de **Binance**
2. **Wallet → Spot** (o Funding)
3. **Deposit**
4. Coin: **USDT**
5. Network: **Tron (TRC20)** ← debe coincidir con la web
6. Copia la address (empieza típico en `T…` en TRC20)
7. Guárdala en un note seguro

En OKX el flujo es igual: **Deposit → USDT → TRC20 → Copy address**.

---

## Paso 3 — Pega la address en la landing

Archivo: `Web/commerce-config.js`

```js
provider: "usdt",
priceUsdt: "9.99",
usdtNetwork: "TRC20",
usdtAddress: "Txxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", // tu address real
contactUrl: "https://t.me/tu_usuario",       // o mailto:tu@email.com
```

Commit + push → Netlify actualiza bonefeed.netlify.app.

---

## Paso 4 — Cómo cobra el comprador

1. Entra a la web → **Buy Pro · USDT**
2. Ve monto `9.99 USDT`, red `TRC20`, y tu address
3. Copia address → retira/envía **exactamente 9.99 USDT** en esa red
4. Pulsa **I paid — contact to unlock** → te escribe por Telegram/email
5. Tú abres Binance → History → Deposit → confirmas el tx
6. Le das Pro (por ahora: unlock manual / código que le envíes)

---

## Paso 5 — Tu checklist operativo (cada venta)

- [ ] ¿Red correcta (TRC20)?
- [ ] ¿Monto ≥ 9.99 USDT? (si mandó de más, ok; si de menos, pedir complemento)
- [ ] ¿Tx confirmada en Binance?
- [ ] Responder al comprador con: link DMG Free + instrucciones Pro
- [ ] Anotar email/Telegram + tx id en una hoja simple

---

## Paso 6 — Cuando crezcas (sin empresa todavía)

1. **Cryptomus / NOWPayments / OxaPay** — checkout automático a wallet
2. Más adelante, si tienes empresa: Binance Pay Merchant

---

## Seguridad

- Nunca pongas seed / private key en la web — solo address de depósito
- No reutilices address de hot wallet con fondos grandes; una deposit address de exchange está bien para empezar
- Si cambias de address, actualiza `commerce-config.js` y pushea al tiro

---

## Qué NO necesitas ahora

- [x] Empresa registrada  
- [x] Binance Pay Merchant KYB  
- [x] Stripe / Lemon Squeezy  
- [ ] Apple Developer — sí lo necesitas después para notarizar el DMG (otro checklist: `SHIP_WEB.md`)
