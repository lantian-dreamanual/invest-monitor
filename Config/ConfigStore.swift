import Foundation

/// 自选板块配置
struct SectorConfig: Codable, Identifiable, Hashable {
    var code: String    // 板块代码
    var name: String    // 板块名称
    var id: String { code }
}

/// 自选基金配置
struct FundConfig: Codable, Identifiable, Hashable {
    var code: String    // 基金代码
    var name: String    // 基金名称
    var id: String { code }
}

/// 用户自选配置（UserDefaults 持久化 JSON）
struct WatchConfig: Codable {
    var sectors: [SectorConfig]
    var funds: [FundConfig]

    static let `default` = WatchConfig(
        sectors: [
            SectorConfig(code: "BK0475", name: "半导体"),
            SectorConfig(code: "BK0547", name: "黄金概念"),
        ],
        funds: [
            FundConfig(code: "161725", name: "招商中证白酒指数C"),
            FundConfig(code: "110011", name: "易方达蓝筹精选"),
            FundConfig(code: "005827", name: "易方达蓝筹精选C"),
        ]
    )
}

/// 配置存储：UserDefaults JSON
final class ConfigStore: ObservableObject {
    @Published var config: WatchConfig {
        didSet { save() }
    }

    private let key = "com.dreamanual.investmonitor.WatchConfig"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let cfg = try? JSONDecoder().decode(WatchConfig.self, from: data) {
            self.config = cfg
        } else {
            self.config = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // MARK: - 增删

    func addSector(_ s: SectorConfig) {
        guard !config.sectors.contains(where: { $0.code == s.code }) else { return }
        config.sectors.append(s)
    }

    func removeSector(_ s: SectorConfig) {
        config.sectors.removeAll { $0.code == s.code }
    }

    func addFund(_ f: FundConfig) {
        guard !config.funds.contains(where: { $0.code == f.code }) else { return }
        config.funds.append(f)
    }

    func removeFund(_ f: FundConfig) {
        config.funds.removeAll { $0.code == f.code }
    }
}