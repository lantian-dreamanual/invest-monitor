import SwiftUI
import AppKit

/// 基金页：对齐黄金/板块页卡片风格，每只基金一张卡片
/// 卡片内分区：净值信息区 → 重仓列表区（表头 + 行）
struct FundView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            if controller.funds.isEmpty {
                // 区分「未配置基金」和「加载中/出错」
                if controller.configStore.config.funds.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        AppIcon(name: "fund", size: 22)
                            .foregroundColor(.secondary)
                        Text("暂未添加基金")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("在设置页「自选基金」中添加")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                        Spacer()
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        if let err = controller.fundErrorMessage {
                            AppIcon(name: "wifi-error", size: 22)
                                .foregroundColor(.secondary)
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ProgressView("加载基金数据…")
                        }
                        Spacer()
                    }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        let fundCount = controller.funds.count
                        ForEach(controller.funds, id: \.quote.code) { fund in
                            FundCard(fund: fund, changes: controller.fundStockChanges, defaultExpanded: fundCount == 1)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 单只基金卡片：一张卡片内完成净值 + 盘中估算 + 重仓列表
/// 重仓列表支持收起/展开，减少多基金时的滚动距离
struct FundCard: View {
    let fund: FundDetail
    let changes: [String: Double]

    @State private var isExpanded = false

    init(fund: FundDetail, changes: [String: Double], defaultExpanded: Bool = false) {
        self.fund = fund
        self.changes = changes
        self._isExpanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ===== 净值信息区 =====
            VStack(alignment: .leading, spacing: 6) {
                // 标题行：名称 + 代码（左侧）  收起/展开按钮（右侧）
                HStack(spacing: 8) {
                    Text(fund.quote.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(fund.quote.code)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !fund.holdings.isEmpty {
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                            AppIcon(name: isExpanded ? "chevron-down" : "chevron-right", size: 12)
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 净值大数 + 涨跌
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.price(fund.quote.nav))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.trend(fund.quote.navChangePct))
                    Text(Format.pct(fund.quote.navChangePct))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.trend(fund.quote.navChangePct))
                    Spacer()
                }
                .padding(.top, 2)

                // 净值日期 + 盘中估算（同行走尾，仅显示估算净值，不显示估算涨跌）
                // 说明：估算涨跌基于今日重仓股行情，与官方净值涨跌（前一净值日基准）不同日，并排易混淆故去掉
                HStack(spacing: 8) {
                    Text("净值日期 \(fund.quote.navDate)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.55))
                    Spacer()
                    if let estNav = fund.estNav {
                        Text("盘中估算")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.55))
                        Text(Format.price(estNav))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // ===== 重仓列表区（收起时隐藏） =====
            if isExpanded {
                Divider().opacity(0.5)
                if fund.holdings.isEmpty {
                    Text("暂无重仓数据")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                } else {
                    holdingHeader
                    Divider().opacity(0.5)
                    let rows = Array(fund.holdings.prefix(5))
                    ForEach(Array(rows.enumerated()), id: \.element.code) { idx, h in
                        holdingRow(idx: idx, holding: h)
                        if idx < rows.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cardBorder, lineWidth: 0.5)
        )
    }

    /// 重仓列表表头
    private var holdingHeader: some View {
        HStack(spacing: 8) {
            Text("#")
                .frame(width: 28, alignment: .leading)
            Text("名称").frame(width: 84, alignment: .leading)
            Spacer()
            Text("占比").frame(width: 48, alignment: .trailing)
            Text("今日涨跌").frame(width: 62, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.primary.opacity(0.7))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.zebraLight)
    }

    /// 单只重仓行（对齐板块成分股行样式）
    private func holdingRow(idx: Int, holding: FundHolding) -> some View {
        HStack(spacing: 8) {
            Text("\(idx + 1)")
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .leading)
            Text(holding.name)
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            Spacer()
            Text(String(format: "%.1f%%", holding.weight))
                .foregroundColor(.secondary)
                .frame(width: 48, alignment: .trailing)
            if let pct = changes[FundEstimator.normalizeCode(holding.code)] {
                Text(Format.pct(pct))
                    .foregroundColor(Color.trend(pct))
                    .frame(width: 62, alignment: .trailing)
            } else {
                Text("--")
                    .foregroundColor(.secondary)
                    .frame(width: 62, alignment: .trailing)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }
}