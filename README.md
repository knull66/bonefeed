# Bonefeed

Notch / menu-bar crypto radar for macOS 14+.  
Watch-only wallets + Binance Spot/Earn + market signals + alerts.

## What you get

- **Notch ticker**: scrolling watchlist prices + PORT  
- **Panel**: RADAR / SPOT / EARN / LOG  
- **Binance** (Pro): Spot + Funding + Simple Earn (read-only), deposits, user data stream  
- **On-chain**: BTC · ETH / MetaMask · SOL  
- **Alerts**: pump/dump, fees, Earn unlock, health, cooldown / quiet hours  
- **Secrets**: AES-GCM + Keychain wrap  

## Run

```bash
cd /path/to/Bonefeed   # or this repo folder
./Scripts/package-app.sh
open ~/Applications/Bonefeed.app
```

## Landing

Live: [https://bonefeed.netlify.app](https://bonefeed.netlify.app)

Local preview:

```bash
open Web/index.html
# or
python3 -m http.server 8080 --directory Web
```

## Identifiers

- Bundle ID: `app.bonefeed.macos`
- Pro IAP: `app.bonefeed.macos.pro`

## Note

Read-only. Does not trade or sign.
