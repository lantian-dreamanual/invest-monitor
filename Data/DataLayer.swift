import Foundation
import SwiftUI

// ============ 全局颜色系统 ============

extension Color {
    // Tailwind v4 色板，饱和度低于系统纯色，深色背景下更柔和
    static let up = Color(red: 0xEF/255, green: 0x44/255, blue: 0x44/255)   // red-500 #EF4444
    static let down = Color(red: 0x22/255, green: 0xC5/255, blue: 0x5E/255) // green-500 #22C55E
    static let flat = Color.secondary // 平

    /// 涨跌颜色：>0 红、<0 绿、==0 灰
    static func trend(_ v: Double) -> Color {
        v > 0 ? .up : (v < 0 ? .down : .flat)
    }
}

// ============ 数据模型 ============

/// 黄金行情（沪金主连，直接 CNY/g）
struct GoldQuote {
    var priceCNY: Double         // 现价 人民币/克
    var prevCNY: Double          // 昨收 人民币/克
    var highCNY: Double          // 今日最高
    var lowCNY: Double           // 今日最低
    var changePct: Double        // 涨跌幅 %
    var time: String             // 更新时间 HH:mm:ss
    var date: String             // 日期 YYYY-MM-DD
}

// ============ 错误 ============
enum FetchError: Error, LocalizedError {
    case badResponse
    case invalidData(String)
    case timeout
    case noConnection

    var errorDescription: String? {
        switch self {
        case .badResponse: return "服务器响应异常"
        case .invalidData: return "数据格式异常"
        case .timeout: return "网络连接超时"
        case .noConnection: return "无法连接服务器"
        }
    }
}

// ============ 网络请求基座 ============

/// 共享 HTTP 客户端：统一 UA/Referer/超时 + JSON 解析 + 友好错误分类
enum NetworkClient {
    static let defaultUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/126.0"
    static let defaultReferer = "https://quote.eastmoney.com/"

    static func getJSON(
        url: URL,
        ua: String = defaultUA,
        referer: String = defaultReferer
    ) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.setValue(ua, forHTTPHeaderField: "User-Agent")
        req.setValue(referer, forHTTPHeaderField: "Referer")
        req.timeoutInterval = 10
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw FetchError.badResponse
            }
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FetchError.invalidData("JSON 解析失败")
            }
            return obj
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw FetchError.timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                throw FetchError.noConnection
            default:
                throw FetchError.badResponse
            }
        }
    }
}

// ============ 黄金聚合服务（东财沪金主连 113.aum，直接 CNY/g） ============
actor GoldService {
    private let base = "https://push2delay.eastmoney.com"

    func fetch() async throws -> GoldQuote {
        let url = URL(string: "\(base)/api/qt/ulist.np/get?fltt=2&secids=113.aum&fields=f2,f3,f4,f5,f6,f12,f14,f15,f16,f17,f18")!
        let json = try await NetworkClient.getJSON(url: url)
        guard let data = json["data"] as? [String: Any],
              let diff = data["diff"] as? [[String: Any]],
              let first = diff.first else {
            throw FetchError.invalidData("沪金解析失败")
        }
        let now = Date()
        let fmtDate = DateFormatter()
        fmtDate.dateFormat = "yyyy-MM-dd"
        let fmtTime = DateFormatter()
        fmtTime.dateFormat = "HH:mm:ss"
        return GoldQuote(
            priceCNY: (first["f2"] as? Double) ?? 0,
            prevCNY: (first["f18"] as? Double) ?? 0,
            highCNY: (first["f15"] as? Double) ?? 0,
            lowCNY: (first["f16"] as? Double) ?? 0,
            changePct: (first["f3"] as? Double) ?? 0,
            time: fmtTime.string(from: now),
            date: fmtDate.string(from: now)
        )
    }
}

// ============ 东财板块/个股 模型 ============

/// 板块指数行情（东财 push2delay）
struct SectorQuote {
    var code: String        // 板块代码
    var name: String        // 板块名称
    var index: Double       // 板块指数点位
    var changePct: Double   // 涨跌幅 %
    var prevIndex: Double   // 昨收
    var amount: Double      // 成交额（元）
}

/// 板块成分股（按成交额）
struct StockQuote {
    var code: String
    var name: String
    var price: Double       // 现价
    var changePct: Double   // 涨跌幅 %
    var amount: Double      // 成交额（元）
}

// ============ 分时线模型 ============

/// 分时线数据点
struct TrendPoint {
    var time: String      // HH:mm
    var price: Double     // 价格（收盘价）
    var avgPrice: Double  // 均价
    var volume: Double    // 成交量
    var amount: Double    // 成交额
}

/// 分时线完整数据
struct TrendData {
    var name: String
    var preClose: Double  // 昨收
    var points: [TrendPoint]
}

// ============ 东财接口解析 ============
enum EastMoneyParser {
    /// 解析板块指数 JSON：ulist.np/get
    static func parseSector(_ json: [String: Any]) -> SectorQuote? {
        guard let data = json["data"] as? [String: Any],
              let diff = data["diff"] as? [[String: Any]],
              let first = diff.first else { return nil }
        return SectorQuote(
            code: (first["f12"] as? String) ?? "",
            name: (first["f14"] as? String) ?? "",
            index: (first["f2"] as? Double) ?? 0,
            changePct: (first["f3"] as? Double) ?? 0,
            prevIndex: (first["f18"] as? Double) ?? 0,
            amount: (first["f6"] as? Double) ?? 0
        )
    }

    /// 解析成分股列表 JSON：clist/get
    static func parseStocks(_ json: [String: Any]) -> [StockQuote] {
        guard let data = json["data"] as? [String: Any],
              let diff = data["diff"] as? [[String: Any]] else { return [] }
        return diff.map {
            StockQuote(
                code: ($0["f12"] as? String) ?? "",
                name: ($0["f14"] as? String) ?? "",
                price: ($0["f2"] as? Double) ?? 0,
                changePct: ($0["f3"] as? Double) ?? 0,
                amount: ($0["f6"] as? Double) ?? 0
            )
        }
    }
}

// ============ 东财板块聚合服务 ============
actor SectorService {
    private let base = "https://push2delay.eastmoney.com/api/qt"

    /// 板块指数
    func fetchIndex(code: String = "BK0475", name: String = "半导体") async throws -> SectorQuote {
        let url = URL(string: "\(base)/ulist.np/get?fltt=2&secids=90.\(code)&fields=f2,f3,f12,f14,f18,f6")!
        let text = try await NetworkClient.getJSON(url: url)
        guard let sector = EastMoneyParser.parseSector(text) else {
            throw FetchError.invalidData("板块解析失败")
        }
        return sector
    }

    /// 批量拉取多个板块指数（secids 逗号连接，一次请求）
    func fetchIndices(codes: [String], names: [String]) async throws -> [SectorQuote] {
        guard !codes.isEmpty else { return [] }
        let secids = codes.map { "90.\($0)" }.joined(separator: ",")
        let url = URL(string: "\(base)/ulist.np/get?fltt=2&secids=\(secids)&fields=f2,f3,f12,f14,f18,f6")!
        let text = try await NetworkClient.getJSON(url: url)
        guard let data = text["data"] as? [String: Any],
              let diff = data["diff"] as? [[String: Any]] else { return [] }
        var result: [SectorQuote] = []
        for item in diff {
            let code = (item["f12"] as? String) ?? ""
            let idx = codes.firstIndex(of: code) ?? 0
            let name = idx < names.count ? names[idx] : ((item["f14"] as? String) ?? "")
            result.append(SectorQuote(
                code: code,
                name: name,
                index: (item["f2"] as? Double) ?? 0,
                changePct: (item["f3"] as? Double) ?? 0,
                prevIndex: (item["f18"] as? Double) ?? 0,
                amount: (item["f6"] as? Double) ?? 0
            ))
        }
        return result
    }

    /// 板块成分股（按成交额排序前 topN）
    func fetchStocks(code: String = "BK0475", topN: Int = 10) async throws -> [StockQuote] {
        let url = URL(string: "\(base)/clist/get?pn=1&pz=\(topN)&po=1&np=1&fltt=2&invt=2&fid=f6&fs=b:\(code)&fields=f2,f3,f6,f12,f14")!
        let text = try await NetworkClient.getJSON(url: url)
        return EastMoneyParser.parseStocks(text)
    }

    /// 批量拉取个股实时涨跌幅（用于基金重仓估算）
    /// - Parameter codes: [代码, 交易所] 元组数组；交易所 1=沪 2=深 5=港
    /// - Returns: 代码 → 涨跌幅%
    func fetchStockChanges(codes: [(code: String, exchange: Int)]) async throws -> [String: Double] {
        guard !codes.isEmpty else { return [:] }
        let secids = codes.map { secid(code: $0.code, exchange: $0.exchange) }.joined(separator: ",")
        let url = URL(string: "\(base)/ulist.np/get?fltt=2&secids=\(secids)&fields=f3,f12")!
        let json = try await NetworkClient.getJSON(url: url)
        guard let data = json["data"] as? [String: Any],
              let diff = data["diff"] as? [[String: Any]] else { return [:] }
        var map: [String: Double] = [:]
        for item in diff {
            if let code = item["f12"] as? String,
               let pct = item["f3"] as? Double {
                map[code] = pct
            }
        }
        return map
    }

    /// 拉取板块分时线数据（当日全天，每分钟一笔）
    func fetchTrends(code: String, name: String) async throws -> TrendData {
        let url = URL(string: "https://push2his.eastmoney.com/api/qt/stock/trends2/get?secid=90.\(code)&fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13&fields2=f51,f52,f53,f54,f55,f56,f57,f58&iscr=0&ndays=1")!
        let json = try await NetworkClient.getJSON(url: url)
        guard let data = json["data"] as? [String: Any],
              let preClose = (data["preClose"] as? Double) ?? (data["preClose"] as? NSNumber)?.doubleValue,
              let trends = data["trends"] as? [String] else {
            throw FetchError.invalidData("分时线解析失败")
        }
        var points: [TrendPoint] = []
        for line in trends {
            let parts = line.split(separator: ",").map(String.init)
            guard parts.count >= 8,
                  let close = Double(parts[2]),
                  let avg = Double(parts[7]),
                  let vol = Double(parts[5]),
                  let amt = Double(parts[6]) else { continue }
            // 时间只取 HH:mm
            let timeStr = parts[0].split(separator: " ").last.map(String.init) ?? parts[0]
            points.append(TrendPoint(time: timeStr, price: close, avgPrice: avg, volume: vol, amount: amt))
        }
        return TrendData(name: name, preClose: preClose, points: points)
    }

    /// 拉取黄金分时线数据（沪金主连 113.aum，CNY/g）
    func fetchGoldTrends() async throws -> TrendData {
        let url = URL(string: "https://push2his.eastmoney.com/api/qt/stock/trends2/get?secid=113.aum&fields1=f1,f2,f3,f4,f5,f6,f7,f8,f9,f10,f11,f12,f13&fields2=f51,f52,f53,f54,f55,f56,f57,f58&iscr=0&ndays=1")!
        let json = try await NetworkClient.getJSON(url: url)
        guard let data = json["data"] as? [String: Any],
              let preClose = (data["preClose"] as? Double) ?? (data["preClose"] as? NSNumber)?.doubleValue,
              let trends = data["trends"] as? [String] else {
            throw FetchError.invalidData("黄金分时线解析失败")
        }
        var points: [TrendPoint] = []
        for line in trends {
            let parts = line.split(separator: ",").map(String.init)
            guard parts.count >= 8,
                  let close = Double(parts[2]),
                  let avg = Double(parts[7]),
                  let vol = Double(parts[5]),
                  let amt = Double(parts[6]) else { continue }
            // 保留完整 "YYYY-MM-DD HH:mm" 用于夜盘跨日映射
            let timeStr = parts[0]
            points.append(TrendPoint(time: timeStr, price: close, avgPrice: avg, volume: vol, amount: amt))
        }
        return TrendData(name: "沪金主连", preClose: preClose, points: points)
    }

    /// 东财 secid 前缀：1=沪 0=深 116=港
    private func secid(code: String, exchange: Int) -> String {
        switch exchange {
        case 1: return "1.\(code)"
        case 5: return "116.\(code)"
        default: return "0.\(code)"
        }
    }
}

// ============ 基金 模型 ============

/// 基金净值（东财 FundMNFInfo）
struct FundQuote {
    var code: String        // 基金代码
    var name: String        // 基金名称
    var nav: Double         // 最新净值
    var navChangePct: Double // 净值日涨跌 %
    var navDate: String     // 净值日期 YYYY-MM-DD
}

/// 基金重仓股（FundMNInverstPosition）
struct FundHolding {
    var code: String        // 股票代码
    var name: String        // 股票名称
    var weight: Double      // 占净值比 %
    var exchange: Int       // 交易所: 1=沪 2=深 5=港
}

/// 基金完整数据（净值 + 重仓 + 估算）
struct FundDetail {
    var quote: FundQuote
    var holdings: [FundHolding]
    var estNav: Double?      // 盘中估算净值（重仓驱动）
    var estChangePct: Double? // 盘中估算涨跌 %
}

// ============ 基金接口解析 ============
enum FundParser {
    /// 解析 FundMNFInfo 净值 JSON
    static func parseQuotes(_ json: [String: Any]) -> [FundQuote] {
        guard let datas = json["Datas"] as? [[String: Any]] else { return [] }
        return datas.compactMap { d in
            guard let code = d["FCODE"] as? String,
                  let name = d["SHORTNAME"] as? String,
                  let navStr = d["NAV"] as? String,
                  let nav = Double(navStr) else { return nil }
            return FundQuote(
                code: code,
                name: name,
                nav: nav,
                navChangePct: (d["NAVCHGRT"] as? String).flatMap(Double.init) ?? 0,
                navDate: (d["PDATE"] as? String) ?? ""
            )
        }
    }

    /// 解析 FundMNInverstPosition 重仓
    static func parseHoldings(_ json: [String: Any]) -> [FundHolding] {
        guard let datas = json["Datas"] as? [String: Any],
              let stocks = datas["fundStocks"] as? [[String: Any]] else { return [] }
        return stocks.compactMap { s in
            guard let code = s["GPDM"] as? String,
                  let name = s["GPJC"] as? String,
                  let wStr = s["JZBL"] as? String,
                  let weight = Double(wStr) else { return nil }
            return FundHolding(
                code: code,
                name: name,
                weight: weight,
                exchange: (s["TEXCH"] as? NSString)?.integerValue ?? 0
            )
        }
    }
}

// ============ 基金聚合服务 ============
actor FundService {
    private let base = "https://fundmobapi.eastmoney.com/FundMNewApi"
    private let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)"
    private let referer = "https://mpservice.eastmoney.com/"
    private let commonParams = "deviceid=Wap&plat=Wap&product=EFund&version=6.2.8"

    /// 批量拉取基金净值
    func fetchQuotes(codes: [String]) async throws -> [FundQuote] {
        guard !codes.isEmpty else { return [] }
        let url = URL(string: "\(base)/FundMNFInfo?Fcodes=\(codes.joined(separator: ","))&\(commonParams)")!
        let json = try await NetworkClient.getJSON(url: url, ua: ua, referer: referer)
        return FundParser.parseQuotes(json)
    }

    /// 拉取单只基金重仓
    func fetchHoldings(code: String) async throws -> [FundHolding] {
        let url = URL(string: "\(base)/FundMNInverstPosition?FCODE=\(code)&\(commonParams)")!
        let json = try await NetworkClient.getJSON(url: url, ua: ua, referer: referer)
        return FundParser.parseHoldings(json)
    }

    /// 合并拉取多只基金详情（净值并发 + 重仓并发）
    func fetchAll(codes: [String]) async throws -> [FundDetail] {
        let quotes = try await fetchQuotes(codes: codes)
        guard !quotes.isEmpty else { return [] }
        // 并发拉取所有基金重仓（保持与净值相同的顺序）
        return try await withTaskGroup(of: (Int, [FundHolding]).self) { group in
            for (i, q) in quotes.enumerated() {
                group.addTask {
                    do {
                        let holdings = try await self.fetchHoldings(code: q.code)
                        return (i, holdings)
                    } catch {
                        return (i, [])
                    }
                }
            }
            var slots: [(Int, [FundHolding])] = []
            slots.reserveCapacity(quotes.count)
            for await r in group {
                slots.append(r)
            }
            slots.sort { $0.0 < $1.0 }
            return quotes.enumerated().map { i, q in
                let holdings = slots[i].1
                return FundDetail(quote: q, holdings: holdings, estNav: nil, estChangePct: nil)
            }
        }
    }
}

// ============ 格式化 ============
enum Format {
    static func price(_ v: Double) -> String { String(format: "%.2f", v) }
    static func pct(_ v: Double) -> String { String(format: "%+.2f%%", v) }

    /// 成交额（元）→ 亿/万 缩写
    static func amount(_ v: Double) -> String {
        if v >= 1e8 { return String(format: "%.1f亿", v / 1e8) }
        if v >= 1e4 { return String(format: "%.0f万", v / 1e4) }
        return String(format: "%.0f", v)
    }
}

// ============ 代码→名称反查服务 ============

/// 通过板块/基金代码反查名称，用于设置页添加时自动填充
enum LookupService {
    /// 板块代码（BKxxxx）→ 板块名称
    static func sectorName(code: String) async -> String? {
        let url = URL(string: "https://push2delay.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=90.\(code)&fields=f12,f14")!
        guard let json = try? await NetworkClient.getJSON(url: url),
              let data = json["data"] as? [String: Any],
              let diff = data["diff"] as? [[String: Any]],
              let first = diff.first,
              let name = first["f14"] as? String else { return nil }
        return name
    }

    /// 基金代码 → 基金名称
    static func fundName(code: String) async -> String? {
        let url = URL(string: "https://fundmobapi.eastmoney.com/FundMNewApi/FundMNFInfo?pageIndex=1&pageSize=1&Fcodes=\(code)&deviceid=Wap&plat=Wap&product=EFund&version=6.2.8")!
        let ua = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)"
        let referer = "https://mpservice.eastmoney.com/"
        guard let json = try? await NetworkClient.getJSON(url: url, ua: ua, referer: referer),
              let datas = json["Datas"] as? [[String: Any]],
              let first = datas.first,
              let name = first["SHORTNAME"] as? String else { return nil }
        return name
    }
}