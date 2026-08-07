import Foundation

/// Shared session that never serves stale crypto balances / tickers from URLCache.
enum LiveURLSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 40
        config.httpAdditionalHeaders = [
            "Cache-Control": "no-cache",
            "Pragma": "no-cache"
        ]
        return URLSession(configuration: config)
    }()
}
