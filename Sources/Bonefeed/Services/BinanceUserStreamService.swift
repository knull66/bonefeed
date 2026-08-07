import Foundation

/// Spot user data stream — triggers faster refresh on balance/deposit activity.
actor BinanceUserStreamService {
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var listenKey: String?
    private var keepAliveTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var onPing: (@Sendable () -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func start(credentials: BinanceCredentials, onActivity: @escaping @Sendable () -> Void) async {
        await stop()
        onPing = onActivity
        do {
            let key = try await createListenKey(credentials: credentials)
            listenKey = key
            guard let url = URL(string: "wss://stream.binance.com:9443/ws/\(key)") else { return }
            let ws = session.webSocketTask(with: url)
            task = ws
            ws.resume()
            receiveTask = Task { await self.receiveLoop(ws) }
            keepAliveTask = Task { await self.keepAliveLoop(credentials: credentials) }
        } catch {
            // Stream is best-effort; polling remains the source of truth.
        }
    }

    func stop() async {
        keepAliveTask?.cancel()
        receiveTask?.cancel()
        keepAliveTask = nil
        receiveTask = nil
        task?.cancel()
        task = nil
        if let key = listenKey {
            listenKey = nil
            try? await closeListenKey(key)
        }
    }

    private func receiveLoop(_ ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    if shouldTrigger(text) {
                        onPing?()
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8), shouldTrigger(text) {
                        onPing?()
                    }
                @unknown default:
                    break
                }
            } catch {
                break
            }
        }
    }

    private func shouldTrigger(_ text: String) -> Bool {
        // balanceUpdate / outboundAccountPosition / executionReport → refresh soon
        text.contains("balanceUpdate")
            || text.contains("outboundAccountPosition")
            || text.contains("\"e\":\"deposit\"")
    }

    private func keepAliveLoop(credentials: BinanceCredentials) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(25 * 60))
            guard !Task.isCancelled, let key = listenKey else { return }
            try? await putListenKey(key, credentials: credentials)
        }
    }

    private func createListenKey(credentials: BinanceCredentials) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.binance.com/api/v3/userDataStream")!)
        request.httpMethod = "POST"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ListenKeyBody.self, from: data)
        return decoded.listenKey
    }

    private func putListenKey(_ key: String, credentials: BinanceCredentials) async throws {
        var request = URLRequest(
            url: URL(string: "https://api.binance.com/api/v3/userDataStream?listenKey=\(key)")!
        )
        request.httpMethod = "PUT"
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        _ = try await session.data(for: request)
    }

    private func closeListenKey(_ key: String) async throws {
        var request = URLRequest(
            url: URL(string: "https://api.binance.com/api/v3/userDataStream?listenKey=\(key)")!
        )
        request.httpMethod = "DELETE"
        _ = try await session.data(for: request)
    }
}

private struct ListenKeyBody: Decodable {
    let listenKey: String
}
