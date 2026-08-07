# Bonefeed Pro — App Store setup

Product ID (must match code): `app.bonefeed.macos.pro`  
Type: **Non-Consumable** (one-time purchase)

## App Store Connect

1. Create the Mac app with bundle id `app.bonefeed.macos`.
2. Features → In-App Purchases → create Non-Consumable.
3. Product ID: `app.bonefeed.macos.pro`
4. Price: e.g. Tier $14.99 (or your choice).
5. Localize display name / description.
6. Submit IAP with the app binary (Paid Apps Agreement must be active).

## Local testing

- Prefer an Xcode project/scheme with `Support/Products.storekit` as StoreKit Configuration.
- Or use a Sandbox Apple ID against App Store Connect products.
- Pre-release builds can use **Pre-release: Unlock Pro** while `ProLimits.allowLocalUnlock` is `true`.

## Who is Pro?

Apple’s servers + the user’s Apple ID. Bonefeed reads `Transaction.currentEntitlements`.  
**Restore Purchases** re-syncs the same Apple ID on another Mac. You do not maintain a user list.
