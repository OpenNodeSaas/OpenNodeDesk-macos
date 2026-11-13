import Foundation

/// CSV 解析/生成 + Excel(.xlsx) 读取：数据可携带，格式透明
enum CSV {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").unicodeScalars)
        if let first = iterator.first, first == "\u{FEFF}" { iterator.removeFirst() }
        var index = 0
        while index < iterator.count {
            let scalar = iterator[index]
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < iterator.count, iterator[index + 1] == "\"" {
                        field.unicodeScalars.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(scalar)
                }
            } else {
                switch scalar {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field); field = ""
                case "\n":
                    row.append(field); field = ""
                    rows.append(row); row = []
                default:
                    field.unicodeScalars.append(scalar)
                }
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    static func encode(_ rows: [[String]]) -> String {
        rows.map { row in
            row.map { value in
                let needsQuote = value.contains(",") || value.contains("\"") || value.contains("\n")
                let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
                return needsQuote ? "\"\(escaped)\"" : escaped
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }
}

// MARK: - Excel

/// 极简 xlsx 读取：走系统 unzip 解包 + XML 解析，避免引入额外依赖
enum XLSXReader {
    static func read(_ url: URL) throws -> [[String]] {
        let shared = sharedStrings(url)
        let sheet = try sheetXML(url)
        let parser = SheetParser(sharedStrings: shared)
        let xml = XMLParser(data: sheet)
        xml.delegate = parser
        guard xml.parse() else { throw ImportError.unreadableTable(L("无法解析 Excel 工作表内容")) }
        return parser.rows
    }

    private static func unzip(_ url: URL, entry: String) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", url.path, entry]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 && !data.isEmpty ? data : nil
    }

    private static func sharedStrings(_ url: URL) -> [String] {
        guard let data = unzip(url, entry: "xl/sharedStrings.xml") else { return [] }
        let parser = SharedStringsParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.strings
    }

    private static func sheetXML(_ url: URL) throws -> Data {
        for entry in ["xl/worksheets/sheet1.xml", "xl/worksheets/sheet.xml"] {
            if let data = unzip(url, entry: entry) { return data }
        }
        throw ImportError.unreadableTable(L("未找到 Excel 工作表，请另存为 CSV 后重试"))
    }

    private final class SharedStringsParser: NSObject, XMLParserDelegate {
        var strings: [String] = []
        private var current: String?
        private var inText = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if elementName == "si" { current = "" }
            if elementName == "t" { inText = true }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inText { current = (current ?? "") + string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "t" { inText = false }
            if elementName == "si" {
                strings.append(current ?? "")
                current = nil
            }
        }
    }

    private final class SheetParser: NSObject, XMLParserDelegate {
        let sharedStrings: [String]
        var rows: [[String]] = []
        private var currentRow: [String] = []
        private var currentValue: String?
        private var currentType = ""
        private var currentColumn = 0
        private var inValue = false

        init(sharedStrings: [String]) { self.sharedStrings = sharedStrings }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "row":
                currentRow = []
            case "c":
                currentType = attributeDict["t"] ?? ""
                currentColumn = Self.columnIndex(attributeDict["r"] ?? "")
                currentValue = nil
            case "v", "t":
                inValue = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inValue { currentValue = (currentValue ?? "") + string }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            switch elementName {
            case "v", "t":
                inValue = false
            case "c":
                var value = currentValue ?? ""
                if currentType == "s", let index = Int(value), sharedStrings.indices.contains(index) {
                    value = sharedStrings[index]
                }
                while currentRow.count < currentColumn { currentRow.append("") }
                if currentRow.count == currentColumn { currentRow.append(value) } else { currentRow[currentColumn] = value }
            case "row":
                if !currentRow.isEmpty { rows.append(currentRow) }
            default:
                break
            }
        }

        /// "BC12" -> 54（0 基列号）
        static func columnIndex(_ reference: String) -> Int {
            var index = 0
            for scalar in reference.unicodeScalars {
                guard scalar.value >= 65, scalar.value <= 90 else { break }
                index = index * 26 + Int(scalar.value - 64)
            }
            return max(0, index - 1)
        }
    }
}

// MARK: - 导入

enum ImportError: LocalizedError {
    case unsupportedFormat
    case unreadableTable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: return L("仅支持 CSV 与 Excel（.xlsx）文件")
        case .unreadableTable(let reason): return reason
        }
    }
}

struct ImportPreview {
    var headers: [String]
    var rows: [[String]]
    var mapping: [AssetField: Int]

    var sample: [[String]] { Array(rows.prefix(8)) }

    var mappedFields: [AssetField] { AssetField.allCases.filter { mapping[$0] != nil } }
}

enum AssetImporter {
    static func readTable(url: URL) throws -> [[String]] {
        switch url.pathExtension.lowercased() {
        case "csv", "txt":
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            if text.isEmpty { throw ImportError.unreadableTable(L("文件为空或不是 UTF-8 编码")) }
            return CSV.parse(text)
        case "xlsx":
            return try XLSXReader.read(url)
        default:
            throw ImportError.unsupportedFormat
        }
    }

    static func preview(url: URL) throws -> ImportPreview {
        let table = try readTable(url: url)
        guard let headers = table.first else { throw ImportError.unreadableTable(L("文件没有可识别的表头")) }
        let mapping = detectMapping(headers: headers)
        guard mapping[.host] != nil || mapping[.name] != nil else {
            throw ImportError.unreadableTable(L("未识别到「主机」或「名称」列，请检查表头"))
        }
        return ImportPreview(headers: headers, rows: Array(table.dropFirst()), mapping: mapping)
    }

    static func detectMapping(headers: [String]) -> [AssetField: Int] {
        var mapping: [AssetField: Int] = [:]
        for (index, header) in headers.enumerated() {
            let normalized = normalize(header)
            guard !normalized.isEmpty else { continue }
            for field in AssetField.allCases where mapping[field] == nil {
                if field.headerAliases.contains(where: { normalize($0) == normalized }) {
                    mapping[field] = index
                    break
                }
            }
        }
        return mapping
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "：", with: "")
            .replacingOccurrences(of: ":", with: "")
    }

    static func buildAssets(rows: [[String]], mapping: [AssetField: Int]) -> (assets: [Asset], failures: [ImportFailure]) {
        var assets: [Asset] = []
        var failures: [ImportFailure] = []

        for (offset, row) in rows.enumerated() {
            let line = offset + 2 // 表头占第 1 行
            func value(_ field: AssetField) -> String {
                guard let index = mapping[field], row.indices.contains(index) else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            var asset = Asset()
            asset.name = value(.name)
            asset.group = value(.group)
            asset.host = value(.host)
            asset.username = value(.username)
            asset.owner = value(.owner)
            asset.jumpHost = value(.jumpHost)
            asset.sshKeyPath = value(.sshKeyPath)
            asset.note1 = value(.note1)
            asset.note2 = value(.note2)
            asset.note3 = value(.note3)
            asset.note4 = value(.note4)

            let protoText = value(.proto).lowercased()
            if protoText.contains("ssh") { asset.proto = .ssh }
            else if protoText.contains("vnc") { asset.proto = .vnc }
            else { asset.proto = .rdp }

            let portText = value(.port)
            if portText.isEmpty {
                asset.port = asset.proto.defaultPort
            } else if let port = Int(portText), port > 0, port <= 65535 {
                asset.port = port
            } else {
                failures.append(ImportFailure(line: line, reason: L("端口非法：{v}").replacingOccurrences(of: "{v}", with: portText), raw: row))
                continue
            }

            if asset.host.isEmpty && asset.name.isEmpty {
                failures.append(ImportFailure(line: line, reason: L("主机与名称均为空"), raw: row))
                continue
            }
            if asset.host.isEmpty {
                failures.append(ImportFailure(line: line, reason: L("主机为空"), raw: row))
                continue
            }
            if asset.name.isEmpty { asset.name = asset.host }

            if let expiryText = value(.expiry).isEmpty ? nil : value(.expiry) {
                if let date = parseDate(expiryText) {
                    asset.expiry = date
                }
                // 无法解析到期日时不阻断导入，仅忽略该字段
            }

            let password = value(.password)
            if !password.isEmpty {
                Keychain.store(password, account: Keychain.passwordAccount(asset.id))
                asset.rememberPassword = true
            }

            assets.append(asset)
        }
        return (assets, failures)
    }

    static func parseDate(_ text: String) -> Date? {
        let formats = ["yyyy-MM-dd", "yyyy/MM/dd", "yyyy.MM.dd", "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd HH:mm:ss", "yyyyMMdd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    /// 失败行可导出，便于用户修正后重试
    static func failureCSV(headers: [String], failures: [ImportFailure]) -> String {
        var rows: [[String]] = [["line", "reason"] + headers]
        for failure in failures {
            rows.append(["\(failure.line)", failure.reason] + failure.raw)
        }
        return CSV.encode(rows)
    }
}

// MARK: - 导出

enum AssetExporter {
    static func rows(assets: [Asset], fields: [AssetField], templates: [ConnectionTemplate]) -> [[String]] {
        let templateNames = Dictionary(uniqueKeysWithValues: templates.map { ($0.id, $0.name) })
        var result: [[String]] = [fields.map { $0.exportHeader }]
        for asset in assets {
            result.append(fields.map { field in
                switch field {
                case .name: return asset.name
                case .group: return asset.group
                case .host: return asset.host
                case .port: return "\(asset.port)"
                case .proto: return asset.proto.rawValue
                case .username: return asset.username
                case .password: return Keychain.secret(account: Keychain.passwordAccount(asset.id)) ?? ""
                case .owner: return asset.owner
                case .expiry: return asset.expiry.map { formatDate($0) } ?? ""
                case .note1: return asset.note1
                case .note2: return asset.note2
                case .note3: return asset.note3
                case .note4: return asset.note4
                case .template: return asset.templateID.flatMap { templateNames[$0] } ?? ""
                case .jumpHost: return asset.jumpHost
                case .sshKeyPath: return asset.sshKeyPath
                }
            })
        }
        return result
    }

    static func csv(assets: [Asset], fields: [AssetField], templates: [ConnectionTemplate]) -> String {
        // 带 BOM，方便 Excel 直接双击打开不乱码
        "\u{FEFF}" + CSV.encode(rows(assets: assets, fields: fields, templates: templates))
    }

    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
