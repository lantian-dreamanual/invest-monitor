import SwiftUI
import AppKit

/// 基金页：净值 + 盘中估算 + 重仓跟踪
struct FundView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            if controller.funds.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    if let err = controller.fundErrorMessage {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ProgressView("加载基金数据…")
                    }
                    Spacer()
                }
            } else {
                if let err = controller.fundErrorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text(err)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(controller.funds, id: \.quote.code) { fund in
                            FundCard(fund: fund, changes: controller.fundStockChanges)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 单只基金卡片
struct FundCard: View {
    let fund: FundDetail
    let changes: [String: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题行
            HStack {
                Text(fund.quote.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(fund.quote.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // 净值 + 估算
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                // 官方净值
                VStack(alignment: .leading, spacing: 2) {
                    Text("官方净值 \(fund.quote.navDate)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Text(Format.price(fund.quote.nav))
                            .font(.title3.bold())
                        Text(Format.pct(fund.quote.navChangePct))
                            .font(.callout)
                            .foregroundColor(Color.trend(fund.quote.navChangePct))
                    }
                }

                Spacer()

                // 盘中估算
                if let est = fund.estChangePct {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("盘中估算")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        HStack(spacing: 4) {
                            if let estNav = fund.estNav {
                                Text(Format.price(estNav))
                                    .font(.title3.bold())
                            }
                            Text(Format.pct(est))
                                .font(.callout)
                                .foregroundColor(Color.trend(est))
                        }
                    }
                }
            }

            Divider()

            // 重仓股实时
            if fund.holdings.isEmpty {
                Text("暂无重仓数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("重仓")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    // 前 5 只重仓
                    ForEach(fund.holdings.prefix(5), id: \.code) { h in
                        HStack {
                            Text(h.name)
                                .font(.caption)
                                .lineLimit(1)
                            Text(String(format: "%.1f%%", h.weight))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            if let pct = changes[FundEstimator.normalizeCode(h.code)] {
                                Text(Format.pct(pct))
                                    .font(.caption)
                                    .foregroundColor(Color.trend(pct))
                            } else {
                                Text("--")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
    }
}