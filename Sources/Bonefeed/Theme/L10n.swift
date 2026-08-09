import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    /// Always bilingual labels in the picker itself.
    var menuLabel: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        }
    }
}

/// Lightweight in-app strings. Default language is English.
enum L10n {
    /// Mirrored from AppStore so services can localize without a store ref.
    nonisolated(unsafe) static var language: AppLanguage = .english

    static func t(_ key: String, lang: AppLanguage? = nil) -> String {
        let l = lang ?? language
        if let s = table[l]?[key] { return s }
        return table[.english]?[key] ?? key
    }

    private static let table: [AppLanguage: [String: String]] = [
        .english: en,
        .spanish: es
    ]

    // MARK: - English (default)

    private static let en: [String: String] = [
        // Brand / chrome
        "brand.tagline": "notch radar for crypto",
        "brand.settingsTitle": "Bonefeed Settings",
        "brand.quit": "Quit Bonefeed",

        // Settings sidebar
        "settings.section.main": "Main",
        "settings.pane.general": "General",
        "settings.pane.pro": "Pro",
        "settings.pane.display": "Display",
        "settings.pane.radar": "Radar",
        "settings.pane.binance": "Binance",
        "settings.pane.wallets": "Wallets",
        "settings.pane.alerts": "Alerts",
        "settings.pane.language": "Language",
        "settings.pane.guide": "Guide",
        "settings.pane.privacy": "Privacy",
        "settings.pane.about": "About",

        // Pro / Free
        "pro.status.free": "Bonefeed Free",
        "pro.status.pro": "Bonefeed Pro",
        "pro.status.freeDetail": "Ticker + 1 wallet. Upgrade for Binance Spot/Earn.",
        "pro.status.proDetail": "Full radar unlocked on this Mac.",
        "pro.freeTitle": "Free includes",
        "pro.free.1": "Live notch ticker (watchlist prices)",
        "pro.free.2": "Up to 3 watchlist coins",
        "pro.free.3": "1 on-chain wallet (BTC / ETH-MetaMask / SOL)",
        "pro.free.4": "Themes: Cyber Dim + Mac Dark",
        "pro.proTitle": "Pro unlocks",
        "pro.pro.1": "Binance API — Spot, Funding, deposits, live stream",
        "pro.pro.2": "Earn positions, rewards, unlock alerts",
        "pro.pro.3": "Unlimited wallets & watchlist",
        "pro.pro.4": "All themes (Binance, Mac Light, Neon…)",
        "pro.pro.5": "Portfolio PnL history in the notch",
        "pro.pro.6": "Binance P2P order alerts (new / paid / done / cancel / appeal)",
        "pro.buy": "Buy Bonefeed Pro",
        "pro.restore": "Restore Purchases",
        "pro.purchasing": "Opening App Store…",
        "pro.restoring": "Restoring…",
        "pro.unlocked": "Pro unlocked. Thanks!",
        "pro.restored": "Purchases restored — Pro is active.",
        "pro.purchaseFailed": "Purchase didn’t complete.",
        "pro.restoreFailed": "Couldn’t restore purchases.",
        "pro.thanks": "Pro is active on this Apple ID.",
        "pro.storeHint": "One-time purchase via App Store. Managed by your Apple ID — Restore on a new Mac.",
        "pro.unlockDebug": "Pre-release: Unlock Pro",
        "pro.lockTest": "Pre-release: Back to Free",
        "pro.debugNote": "Local unlock until App Store IAP goes live. Disable allowLocalUnlock before release.",
        "pro.unlockedDebug": "Pro unlocked (pre-release).",
        "pro.locked": "Back to Free plan.",
        "pro.gate.title": "Pro feature",
        "pro.gate.binance": "Binance Spot / Earn / P2P needs Bonefeed Pro.",
        "pro.gate.wallets": "Free plan: 1 wallet. Unlock Pro for more.",
        "pro.gate.walletsLimit": "Free: {n} on-chain wallet. Pro = unlimited (incl. MetaMask).",
        "pro.gate.watchlist": "Free plan: 3 coins on the radar. Pro unlocks more.",
        "pro.gate.theme": "That theme is Pro. Unlock in Settings → Pro.",
        "pro.seePlan": "See Pro plan",
        "pro.panelLock": "SPOT & EARN need Pro — buy in Settings → Pro",

        // General
        "general.system": "System",
        "general.launchAtLogin": "Launch at Login",
        "general.openLoginItems": "Open Login Items…",
        "general.loginBlocked": "macOS blocked login launch. Approve Bonefeed in Login Items.",
        "general.runtime": "Runtime",
        "general.pause": "Pause live feed",
        "general.sound": "Sound effects",
        "general.pollHint": "Poll: ~10–15s. Watch-only — never trades.",

        // Display
        "display.theme": "Theme",
        "display.themeHint": "Theme applies to notch + panel. Binance & Mac themes included.",

        // Language
        "language.title": "App language",
        "language.hint": "UI copy for Settings, guide, alerts and status. Cyber labels (RADAR / SPOT) stay the same.",
        "language.defaultNote": "Default is English.",

        // Guide
        "guide.title": "Usage guide",
        "guide.blurb": "Bonefeed watches balances and alerts you. It does not buy, sell, or sign.",
        "guide.step1.title": "BINANCE",
        "guide.step1.body": "Settings → Binance → paste a read-only API key → Save → Test.",
        "guide.step2.title": "NOTCH",
        "guide.step2.body": "Click the island for PORT / EARN / SIG. It sits in the menu-bar notch.",
        "guide.step3.title": "LOG",
        "guide.step3.body": "When it pulses, open LOG — deposits and signals land there.",
        "guide.openPanel": "Show guide on panel",
        "guide.footnote": "Watch-only · no trade · no sign",

        // Privacy / terms
        "privacy.termsTitle": "Terms of use",
        "privacy.privacyTitle": "Privacy",
        "privacy.termsBody": """
Bonefeed is a watch-only informational tool for personal use.

• It does not execute trades, transfers, approvals, or signatures.
• You are solely responsible for API keys, wallets you add, and decisions you make from the data shown.
• Market prices and balances come from third parties (e.g. Binance, mempool.space, public RPCs) and may be delayed or wrong.
• Nothing in the app is financial, investment, or tax advice.
• The software is provided “as is”, without warranty. Use at your own risk.
• Do not use a Binance API key with withdraw or trade permissions.
""",
        "privacy.privacyBody": """
What we store — only on this Mac:

• Binance API key/secret encrypted locally (AES-GCM; wrapping key in Keychain).
• Watchlist, wallets, alert thresholds, theme, language, and panel position in UserDefaults / app support.
• Optional portfolio snapshots for 24h PnL.

What we do not do:

• No Bonefeed cloud account. No analytics SDK. No sale of personal data.
• Credentials are not uploaded to our servers (there are none for this app).
• Network calls go to exchanges / public chain APIs you configure by using the feature (Binance, mempool, RPC).

You can clear Binance credentials anytime in Settings → Binance → Clear.
""",
        "privacy.ack": "By using Bonefeed you agree to these terms and the privacy notes above.",

        // Radar settings
        "radar.watchlist": "Market watchlist",
        "radar.watchlistHint": "24h prices & signals on RADAR (Binance public ticker).",
        "radar.custom": "Custom (e.g. ARB)",
        "radar.add": "Add",
        "radar.active": "Active:",
        "radar.reset": "Reset to BTC · ETH · SOL",
        "radar.stablesNote": "Stables (USDT…) can't be watched as tickers.",
        "radar.onchain": "On-chain",
        "radar.onchainHint": "Watch-only BTC / ETH (+Aave HF) / SOL. Binance deposits cover any coin on credit.",

        // Binance
        "binance.apiTitle": "API (read-only)",
        "binance.apiHint": "Binance read-only API key. Bonefeed can view balances — never withdraw or trade.",
        "binance.save": "Save",
        "binance.test": "Test",
        "binance.clear": "Clear",
        "binance.encrypted": "Encrypted on this Mac. Read-only key only — never share your secret.",
        "binance.streamLive": "User data stream live — faster deposit refresh.",

        // Wallets
        "wallets.watch": "Watch address (on-chain)",
        "wallets.hint": "Watch-only addresses. Balance + deposit alerts. No seed / no spend. MetaMask = paste your ETH account address.",
        "wallets.metamaskTip": "MetaMask → Account details → Copy address. Paste the 0x… here. Watch-only — Bonefeed never connects or signs.",
        "wallets.metamaskLabel": "Use label “MetaMask”",
        "wallets.chain": "Chain",
        "wallets.label": "Label",
        "wallets.add": "Add wallet",
        "wallets.empty": "No wallets watched.",
        "wallets.remove": "Remove",
        "wallets.invalidBTC": "Use a BTC address (bc1… / 1… / 3…)",
        "wallets.invalidETH": "Use an ETH / MetaMask address 0x… (40 hex)",
        "wallets.invalidSOL": "Use a SOL base58 address (32–44 chars)",
        "wallets.invalidTitle": "Invalid address",

        // Alerts
        "alerts.notifications": "macOS Notifications",
        "alerts.enable": "Enable notifications",
        "alerts.request": "Request permission",
        "alerts.openSystem": "Open System Settings…",
        "alerts.test": "Test notify",
        "alerts.signals": "Signals",
        "alerts.pumpDump": "24h pump/dump (watchlist)",
        "alerts.dump": "Dump ≤",
        "alerts.pump": "Pump ≥",
        "alerts.signalAssets": "Signal assets (empty = all watchlist):",
        "alerts.filterOff": "Filter off · all radar assets.",
        "alerts.fee": "High BTC fee alert",
        "alerts.feeAt": "Fee ≥",
        "alerts.delivery": "Delivery",
        "alerts.cooldown": "Cooldown",
        "alerts.quiet": "Quiet hours",
        "alerts.from": "From",
        "alerts.to": "to",
        "alerts.quietHint": "Mute pump/dump/fee/earn/health. Deposits + P2P still notify.",
        "alerts.aave": "Aave (ETH)",
        "alerts.aaveHint": "Aave V3 health on watched ETH wallets. Ignore if you don't use Aave.",
        "alerts.health": "Health factor alerts",
        "alerts.healthWarn": "Warn if HF <",
        "alerts.p2p": "Binance P2P",
        "alerts.p2pHint": "Pro · watch-only. Notifies on order status changes. Needs Binance API Reading.",
        "alerts.p2pEnable": "P2P order alerts",
        "alerts.p2pFiat": "Fiat filter",
        "alerts.p2pFiatAuto": "Auto (all)",
        "msg.p2pNew": "P2P · NEW",
        "msg.p2pPaid": "P2P · PAID",
        "msg.p2pRelease": "P2P · RELEASING",
        "msg.p2pDone": "P2P · DONE",
        "msg.p2pCancel": "P2P · CANCEL",
        "msg.p2pAppeal": "P2P · APPEAL",
        "msg.p2pStatus": "P2P · UPDATE",

        // About
        "about.mode": "Mode",
        "about.modeValue": "Market Radar + Binance + Earn",
        "about.chains": "Chains",
        "about.chainsValue": "BTC · ETH (+Aave HF) · SOL",
        "about.data": "Data",
        "about.dataValue": "Binance · mempool · RPC · user stream",
        "about.secrets": "Secrets",
        "about.secretsValue": "AES-GCM + Keychain wrap",
        "about.footer": "Settings here; island panel stays operational.",
        "about.showGuide": "Open usage guide…",
        "about.madeBy": "Made by",
        "about.studio": "Vibes District",
        "about.site": "Website",

        // Panel / notch chrome (keep cyber EN short where possible)
        "panel.refreshHint": "Force refresh Spot / Earn / markets",
        "panel.pnlBag": "bag",
        "panel.pnlMkt": "mkt",
        "panel.tapLive": "tap LIVE to refresh",
        "panel.apiOff": "API off · ⚙ Binance",
        "panel.marketsEmpty": "EMPTY · ⚙ Radar watchlist",
        "panel.logEmpty": "LOG EMPTY",
        "panel.logHint": "Deposits, P2P & earn events appear here.",
        "panel.p2pOff": "P2P alerts off · ⚙ Alerts",
        "panel.p2pEmpty": "NO P2P ORDERS",
        "panel.p2pHint": "Watch-only. Alerts on NEW / PAID / DONE / CANCEL / APPEAL. Fiat filter in Settings → Alerts.",
        "panel.p2pDemoHint": "Test the live order card without a real transfer. Real C2C orders still appear when Binance is connected.",
        "panel.simulateP2P": "> SIMULATE_P2P",
        "panel.advanceP2P": "> ADVANCE_PHASE",
        "panel.clearP2PDemo": "> CLEAR_DEMO",
        "p2p.card.waitBuyerPay": "Pending buyer's payment…",
        "p2p.card.paySeller": "Please pay the seller…",
        "p2p.card.releaseCrypto": "Payment received — release crypto…",
        "p2p.card.waitRelease": "Waiting for seller to release…",
        "p2p.card.releasing": "Releasing crypto…",
        "p2p.card.done": "Trade completed",
        "p2p.card.cancelled": "Order cancelled",
        "p2p.card.appeal": "Order in appeal",
        "p2p.card.update": "Order updated",
        "panel.simulate": "> SIMULATE_DEPOSIT",
        "panel.clearLog": "> CLEAR_LOG",
        "panel.noEarn": "NO EARN POSITIONS",
        "panel.noApi": "NO API  →  ⚙ SETTINGS",
        "panel.spotEmpty": "EMPTY  (funds may be in EARN)",
        "panel.pin": "Pin — keep panel open",
        "panel.unpin": "Unpin",
        "notch.peekHint": "Click to open",
        "notch.p2pDockHint": "Open P2P order status",
        "notch.alertHint": "Click to open LOG",

        // Onboarding overlay
        "onboard.title": "BOOT // FIRST RUN",
        "onboard.settings": "> OPEN_SETTINGS",
        "onboard.ack": "> ACK",

        // Runtime / store messages
        "msg.bootDetail": "Booting radar…",
        "msg.pasteKey": "Paste read-only API key and save.",
        "msg.keyRequired": "API key and secret required.",
        "msg.savedEncrypted": "Saved encrypted (no Keychain prompts).",
        "msg.saveFailed": "In-memory this session (save failed):",
        "msg.cleared": "Credentials cleared.",
        "msg.saveFirst": "Save keys first.",
        "msg.apiMemory": "API in memory.",
        "msg.apiReady": "API ready.",
        "msg.apiMigrated": "API migrated to encrypted store.",
        "msg.noApi": "Set API in Settings",
        "msg.noApiDetail": "No Binance API — on-chain only. Connect keys for Spot balance.",
        "msg.testNotifyBody": "If you see this, macOS notifications work.",
        "msg.simDeposit": "Simulated deposit",
        "msg.simDetail": "Sim — this is what an incoming deposit looks like.",
        "msg.earnSubscribe": "Earn subscribe",
        "msg.earnRedeem": "Earn redeem",
        "msg.unlockSoon": "Unlock soon",
        "msg.depositSimTitle": "Simulated deposit",

        // Deposits / signals
        "deposit.binanceOk": "Credited on Binance",
        "deposit.binancePending": "Binance deposit",
        "deposit.onchainOk": "On-chain confirmed",
        "deposit.onchainMem": "On-chain mempool",
        "deposit.sim": "Simulated deposit",
        "signal.feesHigh": "High fees",
        "signal.btcFees": "BTC fees high",
        "signal.dump": "dump 24h",
        "signal.pump": "pump 24h",
        "signal.signalDump": "Signal: %@ dump",
        "signal.signalPump": "Signal: %@ pump",
        "signal.calm": "Market calm",
        "signal.healthLow": "Health low",
        "signal.aaveRisk": "Aave health risk",
        "signal.radarOffline": "Radar offline",
        "status.healthLow": "Aave health factor low — check collateral/debt.",
        "status.pendingBtc": "Unconfirmed BTC in mempool — Binance credits on confirm.",
        "status.zeroOnchain": "Radar live. On-chain balance 0 — alert on first deposit.",
        "status.listening": "Radar live. Listening for deposits…",
        "status.earnSettling": "Account still $%.2f w/ 0 positions (redeem settling?)",

        // Notifier / login
        "notify.readyBody": "Radar ready for deposits and Earn alerts.",
        "notify.notDetermined": "No permission yet — tap Enable notifications",
        "notify.denied": "Denied — enable in System Settings → Notifications",
        "notify.authorized": "Enabled (check System Settings if missing)",
        "notify.provisional": "Provisional — find Bonefeed in Notifications",
        "notify.ephemeral": "Ephemeral",
        "login.enabled": "On — will open at login",
        "login.disabled": "Off",
        "login.pending": "Pending: approve Bonefeed in Login Items",
        "login.notFound": "Use the app from ~/Applications and re-enable",

        // API errors
        "err.missingCreds": "Missing API key / secret",
        "err.badURL": "Invalid URL",
        "err.decoding": "Unreadable Binance response",
    ]

    // MARK: - Spanish

    private static let es: [String: String] = [
        "brand.tagline": "radar cripto en el notch",
        "brand.settingsTitle": "Ajustes de Bonefeed",
        "brand.quit": "Salir de Bonefeed",

        "settings.section.main": "Principal",
        "settings.pane.general": "General",
        "settings.pane.pro": "Pro",
        "settings.pane.display": "Apariencia",
        "settings.pane.radar": "Radar",
        "settings.pane.binance": "Binance",
        "settings.pane.wallets": "Wallets",
        "settings.pane.alerts": "Avisos",
        "settings.pane.language": "Idioma",
        "settings.pane.guide": "Guía",
        "settings.pane.privacy": "Privacidad",
        "settings.pane.about": "Acerca de",

        "pro.status.free": "Bonefeed Free",
        "pro.status.pro": "Bonefeed Pro",
        "pro.status.freeDetail": "Ticker + 1 wallet. Pro desbloquea Binance Spot/Earn.",
        "pro.status.proDetail": "Radar completo desbloqueado en este Mac.",
        "pro.freeTitle": "Free incluye",
        "pro.free.1": "Ticker live en el notch (precios watchlist)",
        "pro.free.2": "Hasta 3 monedas en el radar",
        "pro.free.3": "1 wallet on-chain (BTC / ETH-MetaMask / SOL)",
        "pro.free.4": "Temas: Cyber Dim + Mac Dark",
        "pro.proTitle": "Pro desbloquea",
        "pro.pro.1": "API Binance — Spot, Funding, depósitos, stream",
        "pro.pro.2": "Earn, rewards y avisos de unlock",
        "pro.pro.3": "Wallets y watchlist ilimitados",
        "pro.pro.4": "Todos los temas (Binance, Mac Light, Neon…)",
        "pro.pro.5": "Historial PnL de portfolio en el notch",
        "pro.pro.6": "Alertas P2P Binance (nueva / pagada / done / cancel / appeal)",
        "pro.buy": "Comprar Bonefeed Pro",
        "pro.restore": "Restaurar compras",
        "pro.purchasing": "Abriendo App Store…",
        "pro.restoring": "Restaurando…",
        "pro.unlocked": "Pro desbloqueado. ¡Gracias!",
        "pro.restored": "Compras restauradas — Pro activo.",
        "pro.purchaseFailed": "La compra no se completó.",
        "pro.restoreFailed": "No se pudieron restaurar las compras.",
        "pro.thanks": "Pro activo en este Apple ID.",
        "pro.storeHint": "Pago único vía App Store. Lo gestiona tu Apple ID — Restaurar en otro Mac.",
        "pro.unlockDebug": "Pre-release: Desbloquear Pro",
        "pro.lockTest": "Pre-release: Volver a Free",
        "pro.debugNote": "Unlock local hasta que el IAP esté en App Store. Pon allowLocalUnlock = false antes de publicar.",
        "pro.unlockedDebug": "Pro desbloqueado (pre-release).",
        "pro.locked": "De vuelta al plan Free.",
        "pro.gate.title": "Función Pro",
        "pro.gate.binance": "Binance Spot / Earn / P2P requiere Bonefeed Pro.",
        "pro.gate.wallets": "Free: 1 wallet. Pro para más.",
        "pro.gate.walletsLimit": "Free: {n} wallet on-chain. Pro = ilimitadas (incl. MetaMask).",
        "pro.gate.watchlist": "Free: 3 monedas en el radar. Pro desbloquea más.",
        "pro.gate.theme": "Ese tema es Pro. Desbloquea en Ajustes → Pro.",
        "pro.seePlan": "Ver plan Pro",
        "pro.panelLock": "SPOT y EARN necesitan Pro — compra en Ajustes → Pro",

        "general.system": "Sistema",
        "general.launchAtLogin": "Abrir al iniciar sesión",
        "general.openLoginItems": "Abrir Ítems de inicio…",
        "general.loginBlocked": "macOS bloqueó el arranque. Aprueba Bonefeed en Ítems de inicio.",
        "general.runtime": "Funcionamiento",
        "general.pause": "Pausar actualizaciones",
        "general.sound": "Sonidos",
        "general.pollHint": "Actualiza cada ~10–15 s. Solo lectura — nunca opera.",

        "display.theme": "Tema",
        "display.themeHint": "El tema aplica al notch y al panel. Incluye Binance y Mac.",

        "language.title": "Idioma de la app",
        "language.hint": "Textos de Ajustes, guía, avisos y estado. Las etiquetas cyber (RADAR / SPOT) se mantienen.",
        "language.defaultNote": "Por defecto: inglés.",

        "guide.title": "Guía de uso",
        "guide.blurb": "Bonefeed mira saldos y te avisa. No compra, vende ni firma.",
        "guide.step1.title": "BINANCE",
        "guide.step1.body": "Ajustes → Binance → pega API solo lectura → Guardar → Probar.",
        "guide.step2.title": "NOTCH",
        "guide.step2.body": "Haz click en el island para PORT / EARN / SIG. Vive en el notch.",
        "guide.step3.title": "LOG",
        "guide.step3.body": "Si parpadea, abre LOG — ahí caen depósitos y señales.",
        "guide.openPanel": "Mostrar guía en el panel",
        "guide.footnote": "Solo lectura · sin trade · sin firma",

        "privacy.termsTitle": "Términos de uso",
        "privacy.privacyTitle": "Privacidad",
        "privacy.termsBody": """
Bonefeed es una herramienta informativa de solo lectura para uso personal.

• No ejecuta trades, transferencias, approvals ni firmas.
• Eres responsable de tus API keys, wallets que agregues y decisiones que tomes con los datos mostrados.
• Precios y saldos vienen de terceros (p. ej. Binance, mempool.space, RPCs públicos) y pueden ir retrasados o fallar.
• Nada en la app es consejo financiero, de inversión o fiscal.
• El software se ofrece “tal cual”, sin garantía. Úsalo bajo tu propio riesgo.
• No uses una API key de Binance con permisos de retiro o trading.
""",
        "privacy.privacyBody": """
Qué guardamos — solo en este Mac:

• API key/secret de Binance cifrados localmente (AES-GCM; clave en Keychain).
• Watchlist, wallets, umbrales, tema, idioma y posición del panel en UserDefaults / Application Support.
• Snapshots opcionales de portfolio para PnL 24h.

Qué no hacemos:

• Sin cuenta cloud de Bonefeed. Sin analytics. Sin venta de datos.
• Las credenciales no se suben a nuestros servidores (esta app no tiene backend propio).
• Las llamadas de red van a exchanges / APIs públicas que usas al activar la función (Binance, mempool, RPC).

Puedes borrar las credenciales en Ajustes → Binance → Borrar.
""",
        "privacy.ack": "Al usar Bonefeed aceptas estos términos y las notas de privacidad.",

        "radar.watchlist": "Lista de mercado",
        "radar.watchlistHint": "Precios y señales 24h en RADAR (ticker público Binance).",
        "radar.custom": "Otra (ej. ARB)",
        "radar.add": "Añadir",
        "radar.active": "Activas:",
        "radar.reset": "Reset a BTC · ETH · SOL",
        "radar.stablesNote": "Stables (USDT…) no sirven como ticker.",
        "radar.onchain": "On-chain",
        "radar.onchainHint": "Solo lectura BTC / ETH (+Aave HF) / SOL. Depósitos Binance cubren cualquier coin al acreditar.",

        "binance.apiTitle": "API (solo lectura)",
        "binance.apiHint": "API key de Binance solo lectura. Ve saldos — nunca retiros ni trades.",
        "binance.save": "Guardar",
        "binance.test": "Probar",
        "binance.clear": "Borrar",
        "binance.encrypted": "Cifrado en este Mac. Solo lectura — nunca compartas el secret.",
        "binance.streamLive": "User stream activo — depósitos más rápidos.",

        "wallets.watch": "Vigilar dirección (on-chain)",
        "wallets.hint": "Solo lectura. Saldo + avisos de depósito. Sin seed / sin gastar. MetaMask = pega tu address ETH.",
        "wallets.metamaskTip": "MetaMask → Detalles de cuenta → Copiar address. Pega el 0x… aquí. Solo lectura — Bonefeed no conecta ni firma.",
        "wallets.metamaskLabel": "Usar nombre “MetaMask”",
        "wallets.chain": "Red",
        "wallets.label": "Nombre",
        "wallets.add": "Añadir wallet",
        "wallets.empty": "Ninguna wallet vigilada.",
        "wallets.remove": "Quitar",
        "wallets.invalidBTC": "Usa address BTC (bc1… / 1… / 3…)",
        "wallets.invalidETH": "Usa address ETH / MetaMask 0x… (40 hex)",
        "wallets.invalidSOL": "Usa address SOL base58 (32–44 chars)",
        "wallets.invalidTitle": "Address inválida",

        "alerts.notifications": "Notificaciones macOS",
        "alerts.enable": "Activar notificaciones",
        "alerts.request": "Pedir permiso",
        "alerts.openSystem": "Ajustes del sistema…",
        "alerts.test": "Probar aviso",
        "alerts.signals": "Señales",
        "alerts.pumpDump": "Pump/dump 24h (watchlist)",
        "alerts.dump": "Dump ≤",
        "alerts.pump": "Pump ≥",
        "alerts.signalAssets": "Assets con señal (vacío = todas):",
        "alerts.filterOff": "Sin filtro · todas las del radar.",
        "alerts.fee": "Alerta fee BTC alta",
        "alerts.feeAt": "Fee ≥",
        "alerts.delivery": "Entrega",
        "alerts.cooldown": "Cooldown",
        "alerts.quiet": "Horas silenciosas",
        "alerts.from": "Desde",
        "alerts.to": "hasta",
        "alerts.quietHint": "Mute pump/dump/fee/earn/health. Depósitos + P2P sí.",
        "alerts.aave": "Aave (ETH)",
        "alerts.aaveHint": "Health Aave V3 en wallets ETH. Ignora si no usas Aave.",
        "alerts.health": "Alertas de health factor",
        "alerts.healthWarn": "Avisar si HF <",
        "alerts.p2p": "Binance P2P",
        "alerts.p2pHint": "Pro · solo lectura. Avisa cambios de estado de órdenes. API Reading.",
        "alerts.p2pEnable": "Alertas de órdenes P2P",
        "alerts.p2pFiat": "Filtro fiat",
        "alerts.p2pFiatAuto": "Auto (todas)",
        "msg.p2pNew": "P2P · NUEVA",
        "msg.p2pPaid": "P2P · PAGADA",
        "msg.p2pRelease": "P2P · LIBERANDO",
        "msg.p2pDone": "P2P · DONE",
        "msg.p2pCancel": "P2P · CANCEL",
        "msg.p2pAppeal": "P2P · APPEAL",
        "msg.p2pStatus": "P2P · UPDATE",

        "about.mode": "Modo",
        "about.modeValue": "Market Radar + Binance + Earn",
        "about.chains": "Cadenas",
        "about.chainsValue": "BTC · ETH (+Aave HF) · SOL",
        "about.data": "Datos",
        "about.dataValue": "Binance · mempool · RPC · user stream",
        "about.secrets": "Secretos",
        "about.secretsValue": "AES-GCM + Keychain",
        "about.footer": "Ajustes aquí; el panel del island es lo operativo.",
        "about.showGuide": "Abrir guía de uso…",
        "about.madeBy": "Hecho por",
        "about.studio": "Vibes District",
        "about.site": "Sitio web",

        "panel.refreshHint": "Forzar refresh Spot / Earn / mercados",
        "panel.pnlBag": "cartera",
        "panel.pnlMkt": "mkt",
        "panel.tapLive": "tap LIVE para refrescar",
        "panel.apiOff": "API off · ⚙ Binance",
        "panel.marketsEmpty": "EMPTY · ⚙ Radar watchlist",
        "panel.logEmpty": "LOG EMPTY",
        "panel.logHint": "Depósitos, P2P y Earn aparecen aquí.",
        "panel.p2pOff": "Alertas P2P off · ⚙ Alerts",
        "panel.p2pEmpty": "SIN ÓRDENES P2P",
        "panel.p2pHint": "Solo lectura. Avisa NEW / PAID / DONE / CANCEL / APPEAL. Fiat en Ajustes → Alerts.",
        "panel.p2pDemoHint": "Prueba la card de orden en vivo sin una transferencia real. Las órdenes C2C reales siguen apareciendo si Binance está conectado.",
        "panel.simulateP2P": "> SIMULATE_P2P",
        "panel.advanceP2P": "> ADVANCE_PHASE",
        "panel.clearP2PDemo": "> CLEAR_DEMO",
        "p2p.card.waitBuyerPay": "Esperando pago del comprador…",
        "p2p.card.paySeller": "Paga al vendedor…",
        "p2p.card.releaseCrypto": "Pago recibido — libera el crypto…",
        "p2p.card.waitRelease": "Esperando que el vendedor libere…",
        "p2p.card.releasing": "Liberando crypto…",
        "p2p.card.done": "Trade completado",
        "p2p.card.cancelled": "Orden cancelada",
        "p2p.card.appeal": "Orden en apelación",
        "p2p.card.update": "Orden actualizada",
        "panel.simulate": "> SIMULATE_DEPOSIT",
        "panel.clearLog": "> CLEAR_LOG",
        "panel.noEarn": "NO EARN POSITIONS",
        "panel.noApi": "NO API  →  ⚙ SETTINGS",
        "panel.spotEmpty": "EMPTY  (funds may be in EARN)",
        "panel.pin": "Pin — deja el panel abierto",
        "panel.unpin": "Unpin",
        "notch.peekHint": "Click para abrir",
        "notch.p2pDockHint": "Abrir estado de orden P2P",
        "notch.alertHint": "Click para abrir LOG",

        "onboard.title": "BOOT // FIRST RUN",
        "onboard.settings": "> OPEN_SETTINGS",
        "onboard.ack": "> ACK",

        "msg.bootDetail": "Iniciando radar…",
        "msg.pasteKey": "Pega API key solo lectura y guarda.",
        "msg.keyRequired": "API key y secret son obligatorios.",
        "msg.savedEncrypted": "Guardado cifrado (sin prompts Keychain).",
        "msg.saveFailed": "En memoria esta sesión (falló guardar):",
        "msg.cleared": "Credenciales borradas.",
        "msg.saveFirst": "Guarda las keys primero.",
        "msg.apiMemory": "API en memoria.",
        "msg.apiReady": "API lista.",
        "msg.apiMigrated": "API migrada a almacén cifrado.",
        "msg.noApi": "Configura API en Settings",
        "msg.noApiDetail": "Sin API Binance — solo on-chain. Conecta keys para Spot.",
        "msg.testNotifyBody": "Si ves esto, las notificaciones macOS funcionan.",
        "msg.simDeposit": "Depósito simulado",
        "msg.simDetail": "Sim — así se ve un depósito entrando.",
        "msg.earnSubscribe": "Suscripción Earn",
        "msg.earnRedeem": "Redeem Earn",
        "msg.unlockSoon": "Unlock pronto",
        "msg.depositSimTitle": "Depósito simulado",

        "deposit.binanceOk": "Acreditado en Binance",
        "deposit.binancePending": "Depósito Binance",
        "deposit.onchainOk": "On-chain confirmado",
        "deposit.onchainMem": "On-chain mempool",
        "deposit.sim": "Depósito simulado",
        "signal.feesHigh": "Fees altas",
        "signal.btcFees": "BTC fees altas",
        "signal.dump": "dump 24h",
        "signal.pump": "pump 24h",
        "signal.signalDump": "Señal: %@ dump",
        "signal.signalPump": "Señal: %@ pump",
        "signal.calm": "Mercado calmado",
        "signal.healthLow": "Health baja",
        "signal.aaveRisk": "Aave health riesgo",
        "signal.radarOffline": "Radar offline",
        "status.healthLow": "Health factor Aave bajo — revisa colateral/deuda.",
        "status.pendingBtc": "BTC sin confirmar en mempool — Binance acredita al confirmar.",
        "status.zeroOnchain": "Radar activo. Balance on-chain 0 — aviso al primer depósito.",
        "status.listening": "Radar activo. Escuchando depósitos…",
        "status.earnSettling": "Account aún $%.2f con 0 posiciones (¿redeem pendiente?)",

        "notify.readyBody": "Radar listo para avisarte de depósitos y Earn.",
        "notify.notDetermined": "Sin permiso aún — pulsa Enable notifications",
        "notify.denied": "Denegadas — actívalas en Ajustes del Sistema → Notificaciones",
        "notify.authorized": "Activadas (revisa Ajustes del Sistema si no ves nada)",
        "notify.provisional": "Provisionales — busca Bonefeed en Notificaciones",
        "notify.ephemeral": "Efímeras",
        "login.enabled": "Activo — abrirá al iniciar sesión",
        "login.disabled": "Off",
        "login.pending": "Pendiente: aprueba Bonefeed en Login Items",
        "login.notFound": "Usa la app de ~/Applications y vuelve a activar",

        "err.missingCreds": "Faltan API key / secret",
        "err.badURL": "URL inválida",
        "err.decoding": "Respuesta Binance ilegible",
    ]
}
