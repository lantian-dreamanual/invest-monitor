import SwiftUI

// ============ 设计系统：共享组件 ============

/// 交易状态标签
struct MarketStatusBadge: View {
    let isOpen: Bool

    var body: some View {
        Text(isOpen ? "交易中" : "已收盘")
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(isOpen ? Color.up.opacity(0.12) : Color.gray.opacity(0.12))
            .foregroundColor(isOpen ? .up : .secondary)
            .cornerRadius(4)
    }
}

/// 统一行情头部：标签 + 状态 → 大价格 → 涨跌 + 次要信息
struct PriceHeader: View {
    let title: String
    let marketOpen: Bool?           // nil = 不显示状态标签
    let price: String               // 格式化后的价格文本
    let changePct: Double           // 涨跌幅 %
    let secondary: String?          // 可选次要信息，如 "成交额 12.3亿"

    var body: some View {
        VStack(spacing: 4) {
            // 标签行
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let open = marketOpen {
                    MarketStatusBadge(isOpen: open)
                }
            }

            // 大价格
            Text(price)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Color.trend(changePct))

            // 涨跌幅 + 次要信息
            HStack(spacing: 16) {
                Text(Format.pct(changePct))
                    .font(.callout.weight(.semibold))
                    .foregroundColor(Color.trend(changePct))
                if let sec = secondary {
                    Text(sec)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
}
