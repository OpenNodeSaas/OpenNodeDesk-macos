import Foundation

/// 云端同步：先拉取预览，勾选后再落库，不直接覆盖本地
enum SyncError: LocalizedError {
    case invalidEndpoint
    case unauthorized
    case server(Int)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint: return L("同步服务地址无效")
        case .unauthorized: return L("令牌无效或已过期（HTTP 401/403）")
        case .server(let code): return L("服务返回异常状态：HTTP {v}").replacingOccurrences(of: "{v}", with: "\(code)")
        case .decoding(let reason): return L("返回内容无法解析：{v}").replacingOccurrences(of: "{v}", with: reason)
        case .transport(let reason): return L("网络请求失败：{v}").replacingOccurrences(of: "{v}", with: reason)
        }
    }

    var diagnostic: Diagnostic {
        Diagnostic(
            cause: errorDescription ?? L("同步失败"),
            suggestions: [
                L("确认服务地址可访问、路径以 / 结尾表示接口根地址"),
                L("确认令牌未过期且具备读取资产权限"),
                L("断网时本产品仍可离线使用，同步失败不影响本地数据")
            ]
        )
    }
}

enum SyncClient {
    /// 远端资产结构（字段可缺省，解码后补齐默认值）
    struct RemoteAsset: Decodable {
        var name: String?
        var group: String?
        var host: String?
        var port: Int?
        var proto: String?
        var protocolName: String?
        var username: String?
        var owner: String?
        var expiry: String?
        var note1: String?
        var note2: String?
        var note3: String?
        var jumpHost: String?

        enum CodingKeys: String, CodingKey {
            case name, group, host, port, proto, username, owner, expiry, note1, note2, note3, jumpHost
            case protocolName = "protocol"
        }
    }

    private struct Envelope: Decodable {
        var assets: [RemoteAsset]?

        init(from decoder: Decoder) throws {
            if let list = try? decoder.singleValueContainer().decode([RemoteAsset].self) {
                assets = list
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            assets = try container.decodeIfPresent([RemoteAsset].self, forKey: .assets)
        }

        enum CodingKeys: String, CodingKey { case assets }
    }

    static func fetch(endpoint: String, token: String, timeout: TimeInterval = 15) async throws -> [Asset] {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SyncError.invalidEndpoint }
        let base = trimmed.hasSuffix("/") ? trimmed : trimmed + "/"
        guard let url = URL(string: base + "assets") else { throw SyncError.invalidEndpoint }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SyncError.transport(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            if http.statusCode == 401 || http.statusCode == 403 { throw SyncError.unauthorized }
            if http.statusCode >= 400 { throw SyncError.server(http.statusCode) }
        }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw SyncError.decoding(error.localizedDescription)
        }

        return (envelope.assets ?? []).compactMap { remote in
            guard let host = remote.host, !host.isEmpty else { return nil }
            var asset = Asset()
            asset.name = remote.name ?? host
            asset.group = remote.group ?? ""
            asset.host = host
            let protoText = (remote.proto ?? remote.protocolName ?? "").lowercased()
            asset.proto = protoText.contains("ssh") ? .ssh : (protoText.contains("vnc") ? .vnc : .rdp)
            asset.port = remote.port ?? asset.proto.defaultPort
            asset.username = remote.username ?? ""
            asset.owner = remote.owner ?? ""
            asset.jumpHost = remote.jumpHost ?? ""
            asset.note1 = remote.note1 ?? ""
            asset.note2 = remote.note2 ?? ""
            asset.note3 = remote.note3 ?? ""
            if let expiry = remote.expiry { asset.expiry = AssetImporter.parseDate(expiry) }
            return asset
        }
    }
}
