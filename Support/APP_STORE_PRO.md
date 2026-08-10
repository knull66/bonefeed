# Bonefeed Pro + VIP — App Store setup

| Product | ID | Suggested price |
|---------|----|-----------------|
| Pro | `app.bonefeed.macos.pro` | $9.99 |
| VIP Signals | `app.bonefeed.macos.vip` | $14.99 (includes Pro entitlements) |

Type: **Non-Consumable** (one-time purchase) for both.

## App Store Connect

1. Create the Mac app with bundle id `app.bonefeed.macos`.
2. Features → In-App Purchases → create two Non-Consumables with the IDs above.
3. Localize display name / description (VIP = tight signal desk, watch-only).
4. Submit IAPs with the app binary (Paid Apps Agreement must be active).

## VIP behavior in app

- VIP purchase sets `isVIP` **and** `isPro`.
- VIP desk: ±2.5% pump/dump, fee warn at 25 sat/vB, 15 min cooldown (toggle in Settings → Alerts).
- Never places trades.

## Local testing

- Prefer an Xcode project/scheme with `Support/Products.storekit` as StoreKit Configuration.
- Or use a Sandbox Apple ID against App Store Connect products.
- Pre-release builds can use **Pre-release: Unlock Pro** while `ProLimits.allowLocalUnlock` is `true`.

## Who is Pro?

Apple’s servers + the user’s Apple ID. Bonefeed reads `Transaction.currentEntitlements`.  
**Restore Purchases** re-syncs the same Apple ID on another Mac. You do not maintain a user list.
