import Foundation

/// 预警标的类型
enum AlertTargetType: String, Codable {
    case goldCNY = "黄金CNY"      // 黄金折算价 CNY/g
    case sector = "板块"          // 板块涨跌幅
    case fund = "基金"            // 基金估算/净值
}

/// 预警方向
enum AlertDirection: String, Codable {
    case above = "≥"   // 价格涨到阈值
    case below = "≤"   // 价格跌到阈值
}

/// 基金预警基准：净值价位 / 涨跌幅百分比
enum FundMetric: String, Codable, CaseIterable {
    case nav = "净值"       // 基金净值价位（如 1.50）
    case changePct = "涨跌幅" // 涨跌幅百分比（如 -2.50%）
}

/// 预警规则
struct AlertRule: Codable, Identifiable, Hashable {
    var id: String            // UUID
    var targetType: AlertTargetType
    var targetCode: String     // 黄金留空、板块如 BK0475、基金如 161725
    var targetName: String     // 显示名
    var direction: AlertDirection
    var threshold: Double       // 阈值
    var label: String           // 提醒文案，如「第1档止盈 · 建议卖1/3」
    var enabled: Bool           // 单条规则开关
    var triggered: Bool         // 已触发标记（防重复）
    var triggeredAt: Date?      // 触发时间
    /// 基金预警基准（仅 targetType == .fund 有意义，默认净值）
    var fundMetric: FundMetric?

    /// 触发后标记
    mutating func markTriggered() {
        triggered = true
        triggeredAt = Date()
    }

    /// 价格回落过阈值后重置（恢复可再次触发）
    mutating func reset() {
        triggered = false
        triggeredAt = nil
    }
}
