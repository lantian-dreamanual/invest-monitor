import Foundation

/// 预警引擎：比对最新数据与规则阈值，管理触发/恢复状态
enum AlertEngine {

    /// 评估单条规则是否应触发
    /// - Parameters:
    ///   - rule: 预警规则
    ///   - value: 当前价格/涨跌幅
    /// - Returns: 是否应发通知（仅在规则启用、未触发、且满足条件时返回 true）
    static func shouldTrigger(rule: AlertRule, value: Double) -> Bool {
        guard rule.enabled, !rule.triggered else { return false }
        switch rule.direction {
        case .above:
            return value >= rule.threshold
        case .below:
            return value <= rule.threshold
        }
    }

    /// 判断已触发规则是否应恢复（价格回落过阈值）
    /// - Returns: true 表示价格已离开触发区域，可重置 triggered
    static func shouldReset(rule: AlertRule, value: Double) -> Bool {
        guard rule.enabled, rule.triggered else { return false }
        switch rule.direction {
        case .above:
            // ≥ 阈值触发后，价格回落到阈值以下一定幅度（1%）才重置
            return value < rule.threshold * 0.99
        case .below:
            // ≤ 阈值触发后，价格回升到阈值以上一定幅度（1%）才重置
            return value > rule.threshold * 1.01
        }
    }

    /// 批量检查所有规则，返回需要触发和需要重置的规则索引
    static func checkAll(rules: [AlertRule], values: [String: Double]) -> (trigger: [Int], reset: [Int]) {
        var trigger: [Int] = []
        var reset: [Int] = []
        for (i, rule) in rules.enumerated() {
            let key = ruleKey(rule)
            guard let value = values[key] else { continue }
            if shouldTrigger(rule: rule, value: value) {
                trigger.append(i)
            } else if shouldReset(rule: rule, value: value) {
                reset.append(i)
            }
        }
        return (trigger, reset)
    }

    /// 构造规则 → 当前值的映射 key
    static func ruleKey(_ rule: AlertRule) -> String {
        switch rule.targetType {
        case .goldCNY: return "goldCNY"
        case .sector: return "sector_\(rule.targetCode)"
        case .fund:
            // 基金按基准区分：净值 / 涨跌幅
            if rule.fundMetric == .changePct {
                return "fund_pct_\(rule.targetCode)"
            }
            return "fund_nav_\(rule.targetCode)"
        }
    }

    /// 从当前数据提取所有标的的最新值
    /// 注意：基金预警只使用官方净值(fund.quote.nav)和官方涨跌幅(fund.quote.navChangePct)，
    /// 不使用盘中估算值（估算值基于重仓股实时行情推算，精度有限，不适合触发预警）
    static func extractValues(gold: GoldQuote?, sectors: [SectorQuote], funds: [FundDetail]) -> [String: Double] {
        var map: [String: Double] = [:]
        if let g = gold {
            map["goldCNY"] = g.priceCNY
        }
        for s in sectors {
            map["sector_\(s.code)"] = s.changePct
        }
        for f in funds {
            // 基金涨跌幅：只用官方净值涨跌幅，不用盘中估算
            map["fund_pct_\(f.quote.code)"] = f.quote.navChangePct
            // 基金净值：只用官方净值，不用盘中估算
            map["fund_nav_\(f.quote.code)"] = f.quote.nav
        }
        return map
    }
}
