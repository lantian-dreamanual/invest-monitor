import Foundation

/// 基金盘中模拟估值：重仓股权重 × 实时个股涨跌
/// 估算涨跌% = Σ(权重 × 个股涨跌%) / Σ(权重)
enum FundEstimator {

    /// 计算单只基金的估算涨跌
    /// - Parameters:
    ///   - holdings: 重仓股（含权重）
    ///   - stockMap: 重仓股代码 → 实时涨跌%（key 为去前缀代码，如 "300308"）
    /// - Returns: 加权估算涨跌%（只统计有实时行情的重仓）
    static func estimateChangePct(holdings: [FundHolding], stockMap: [String: Double]) -> Double? {
        var weightSum = 0.0
        var weighted = 0.0
        for h in holdings {
            // 代码统一去前缀（沪 600/688、深 300/002、港 06869 等）
            let key = normalizeCode(h.code)
            if let pct = stockMap[key] {
                weightSum += h.weight
                weighted += h.weight * pct
            }
        }
        guard weightSum > 0 else { return nil }
        return weighted / weightSum
    }

    /// 估算净值 = 最新净值 × (1 + 估算涨跌%)
    static func estimateNav(nav: Double, changePct: Double) -> Double {
        nav * (1 + changePct / 100)
    }

    /// 统一代码格式：东财重仓 GPDM 可能是 "300308"，行情接口需要去市场前缀
    static func normalizeCode(_ code: String) -> String {
        // 6 位纯数字，无需处理；带 sh/sz 前缀则去前缀
        if code.count > 6 {
            return String(code.suffix(6))
        }
        return code
    }
}