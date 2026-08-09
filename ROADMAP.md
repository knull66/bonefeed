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

## Next (v1 ship)
1. [ ] Apple Developer Program (annual)
2. [ ] App Store Connect — Mac app + IAP Non-Consumable `app.bonefeed.macos.pro`
3. [ ] Code sign + notarize (replace ad-hoc)
4. [ ] Set `ProLimits.allowLocalUnlock = false` before release
5. [ ] Sandbox test: Buy + Restore Purchases
6. [x] Landing page — live at https://bonefeed.netlify.app (download URL still pending DMG/App Store)
7. [ ] Screenshots + DMG/zip for public download
8. [ ] Closed beta 1–2 weeks (5–10 users with Binance)

## Later (optional)
- [ ] Setapp
- [ ] Annual subscription (if one-time underperforms)
- [ ] More exchanges / chains
- [ ] Polish notch / themes from beta feedback

## Identifiers
- Bundle: `app.bonefeed.macos`
- Pro IAP: `app.bonefeed.macos.pro`
- Setup notes: `Support/APP_STORE_PRO.md`
