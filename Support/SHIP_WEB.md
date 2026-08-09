# Bonefeed — Ship on the web (notarize + payments)

Goal: sell Free download + Pro ($9.99 USDT) from [bonefeed.netlify.app](https://bonefeed.netlify.app), notarized for Gatekeeper, without waiting on Mac App Store.

**Payments (VE-friendly):** manual USDT — see **`Support/PAY_USDT.md`** (no company, no Binance Pay Merchant).

---

## Phase 0 — Money plumbing (USDT, ~30 min)

- [ ] Follow `Support/PAY_USDT.md`
- [ ] Binance/OKX deposit address USDT **TRC20**
- [ ] Paste into `Web/commerce-config.js` → `usdtAddress` + `contactUrl`
- [ ] Commit + push
- [ ] Test **Buy Pro · USDT** modal on the live site

---

## Phase 1 — Apple Developer (required for notarize)

- [ ] Enroll [Apple Developer Program](https://developer.apple.com/programs/) — **$99/year**
- [ ] Wait until membership is Active
- [ ] Xcode → Settings → Accounts → download certificates
- [ ] Create **Developer ID Application** certificate (for distribution outside App Store)
- [ ] Note your **Team ID** (10 chars) and signing identity name:
  - Example: `Developer ID Application: Your Name (TEAMID)`

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

---

## Phase 2 — Notary credentials (one-time)

App-specific password: [appleid.apple.com](https://appleid.apple.com) → Sign-In → App-Specific Passwords.

```bash
xcrun notarytool store-credentials "bonefeed-notary" \
  --apple-id "you@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

- [ ] Credentials stored (profile name: `bonefeed-notary`)
- [ ] Export for local shells (never commit):

```bash
export BONEFEED_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export BONEFEED_NOTARY_PROFILE="bonefeed-notary"
```

---

## Phase 3 — Build, sign, notarize, DMG

```bash
# From repo root — builds Dist/Bonefeed.app, notarizes, writes Dist/Bonefeed-1.x.x.dmg
./Scripts/notarize.sh
```

Checklist after the script:

- [ ] `Dist/Bonefeed.app` exists
- [ ] `codesign -dv --verbose=4 Dist/Bonefeed.app` shows Developer ID (not ad-hoc)
- [ ] `spctl -a -vv Dist/Bonefeed.app` → accepted
- [ ] DMG opens on a clean Mac / VM without “unidentified developer”
- [ ] First launch: notifications + notch still work

Manual fallback (if script fails): see comments inside `Scripts/notarize.sh`.

---

## Phase 4 — Host the DMG

Pick one:

| Host | Notes |
|------|--------|
| **GitHub Releases** | Easy; public download URL |
| **Cloudflare R2 / S3** | Good for bandwidth |
| **Lemon Squeezy file** | Attach Free build to a $0 product, or host Pro-only |

- [ ] Upload notarized DMG
- [ ] Copy public HTTPS URL into `Web/commerce-config.js` → `downloadUrl`
- [ ] Commit + push → Netlify redeploy

---

## Phase 5 — Landing checkout (already wired)

Files:

- `Web/commerce-config.js` — your URLs
- `Web/commerce.js` — enables Buy / Download buttons
- Landing sections `#download` and `#pro`

- [ ] Set `checkoutUrl` (Lemon Squeezy)
- [ ] Set `downloadUrl` (DMG)
- [ ] Hard-refresh production site
- [ ] Click **Buy Pro** → Lemon Squeezy checkout opens
- [ ] Click **Download Free** → DMG downloads

### Lemon Squeezy overlay (optional polish)

In Lemon Squeezy → Product → Share → Overlay. Then set:

```js
checkoutUrl: "https://yourstore.lemonsqueezy.com/checkout/buy/xxxxxxxx",
useLemonOverlay: true,
```

And keep the Lemon.js script tag already in `index.html`.

### Paddle instead

1. Create Paddle product + price $9.99  
2. Get the **Pay link** or Price ID  
3. In `commerce-config.js`:

```js
provider: "paddle",
checkoutUrl: "https://pay.paddle.com/checkout/xxxxx",
```

---

## Phase 6 — Pro entitlement (after first sales)

Today Pro unlocks via:

- StoreKit IAP (App Store path), or
- Local debug unlock (`ProLimits.allowLocalUnlock`)

For web sales you still need one of:

1. **License key** from Lemon Squeezy → paste in Settings (to build)  
2. **Manual** unlock codes you email buyers (short-term)  
3. Ship App Store IAP later and keep web as Free-only download

- [ ] Decide: license keys vs App Store IAP vs both
- [ ] Until license UI ships: fulfill Pro manually / keep `allowLocalUnlock` for testers only
- [ ] Before public paid release: set `ProLimits.allowLocalUnlock = false`

---

## Phase 7 — Go live smoke test

- [ ] Fresh Mac user account
- [ ] Download Free from site → install → runs Free tier
- [ ] Buy Pro with Lemon Squeezy test mode
- [ ] Confirm payment email + payout dashboard
- [ ] Support email on the site / LS store

---

## Cost reality check

| Item | Cost |
|------|------|
| Apple Developer | $99 / year |
| Lemon Squeezy fees | ~5% + payment fees (see their site) |
| Break-even at $9.99 Pro | ~**11–12 sales** covers Apple for the year |

---

## Order of operations (shortest path)

1. Apple Developer ($99)  
2. Notary credentials + `./Scripts/notarize.sh`  
3. Host DMG → `downloadUrl`  
4. Lemon Squeezy product → `checkoutUrl`  
5. Push landing config  
6. License / IAP entitlement (next engineering sprint)
