import Foundation

/// Aave V3 Ethereum health factor via public JSON-RPC `eth_call`.
actor AaveHealthService {
    private let session: URLSession
    /// Aave V3 Pool on Ethereum mainnet.
    private let poolAddress = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2"
    private let rpcURL = URL(string: "https://ethereum.publicnode.com")!

    init(session: URLSession = LiveURLSession.shared) {
        self.session = session
    }

    /// Returns health factor, or nil if no debt / call failed / address invalid.
    func fetchHealthFactor(address: String) async -> Double? {
        let clean = normalizeAddress(address)
        guard clean.count == 40 else { return nil }

        // getUserAccountData(address) → selector bf92857c
        let data = "0xbf92857c" + String(repeating: "0", count: 24) + clean
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_call",
            "params": [
                ["to": poolAddress, "data": data],
                "latest"
            ]
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.timeoutInterval = 15

        do {
            let (respData, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            guard
                let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
                let hex = json["result"] as? String,
                hex.hasPrefix("0x"),
                hex.count >= 2 + 64 * 6
            else { return nil }

            let hexBody = String(hex.dropFirst(2))
            // Word 6 (index 5): healthFactor, 32 bytes each.
            let start = hexBody.index(hexBody.startIndex, offsetBy: 64 * 5)
            let end = hexBody.index(start, offsetBy: 64)
            let hfHex = String(hexBody[start..<end])
            guard let hfWei = hexToDecimal(hfHex) else { return nil }

            // Aave uses 1e18 fixed point. Max uint256 ≈ no debt.
            if hfWei > Decimal(string: "1e30")! { return nil }
            let hf = NSDecimalNumber(decimal: hfWei / Decimal(string: "1e18")!).doubleValue
            guard hf.isFinite, hf > 0 else { return nil }
            return hf
        } catch {
            return nil
        }
    }

    private func normalizeAddress(_ address: String) -> String {
        var a = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if a.hasPrefix("0x") { a = String(a.dropFirst(2)) }
        return a
    }

    private func hexToDecimal(_ hex: String) -> Decimal? {
        var value = Decimal(0)
        let base = Decimal(16)
        for ch in hex {
            guard let digit = Int(String(ch), radix: 16) else { return nil }
            value = value * base + Decimal(digit)
        }
        return value
    }
}
