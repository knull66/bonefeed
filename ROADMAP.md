# Bonefeed — Roadmap

## Done
- [x] Core product: notch ticker, panel RADAR / SPOT / EARN / LOG
- [x] Binance Spot / Funding / Earn (read-only) + deposits + user stream
- [x] Binance P2P order alerts (Pro) — new / paid / release / done / cancel / appeal
- [x] On-chain wallets BTC / ETH (MetaMask address) / SOL + Aave HF
- [x] Alerts, quiet hours, themes (incl. BLVCK), EN/ES, guide, privacy
- [x] Free vs Pro gates + StoreKit 2 wiring (`app.bonefeed.macos.pro`)
- [x] Rebrand Chain Island → Bonefeed (`app.bonefeed.macos`)
- [x] Notch hover morph + peek

## Next (v1 ship — web first)
Full checklist: `Support/SHIP_WEB.md`

1. [ ] Apple Developer Program (annual) — needed to notarize
2. [ ] Developer ID sign + notarize + DMG (`./Scripts/notarize.sh`)
3. [ ] Host DMG → set `Web/commerce-config.js` `downloadUrl`
4. [ ] USDT Pro checkout — paste `usdtAddress` + `contactUrl` (`Support/PAY_USDT.md`)
5. [ ] Landing Buy/Download live (USDT modal wired; waiting on address + DMG)
6. [ ] License-key unlock in app (or fulfill Pro manually until then)
7. [ ] Set `ProLimits.allowLocalUnlock = false` before paid public release
8. [ ] Closed beta 1–2 weeks (5–10 users with Binance)

## Later — Mac App Store
1. [ ] App Store Connect — Mac app + IAP Non-Consumable `app.bonefeed.macos.pro`
2. [ ] Sandbox test: Buy + Restore Purchases
3. [ ] Screenshots for App Store listing

## Later (optional)
- [ ] Setapp
- [ ] Annual subscription (if one-time underperforms)
- [ ] More exchanges / chains
- [ ] Polish notch / themes from beta feedback

## Identifiers
- Bundle: `app.bonefeed.macos`
- Pro IAP: `app.bonefeed.macos.pro`
- Setup notes: `Support/APP_STORE_PRO.md`
