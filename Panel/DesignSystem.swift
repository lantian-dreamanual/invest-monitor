import SwiftUI

// ============ 设计系统：共享组件 ============

/// 交易状态标签
struct MarketStatusBadge: View {
    let isOpen: Bool

    var body: some View {
        Text(isOpen ? "交易中" : "已收盘")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(isOpen ? Color.up.opacity(0.12) : Color.gray.opacity(0.12))
            .foregroundColor(isOpen ? .up : .secondary)
            .cornerRadius(6)
    }
}

// ============ 设计系统：表单组件 ============

/// 表单标签：统一 12pt secondary，与控件间距 6pt
struct FormLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
    }
}

/// 自定义输入框：可见边框 + 聚焦高亮，解决系统默认边框不可见问题
/// - 高度 28pt，圆角 6pt，边框 gray.opacity(0.35) 常态 / blue.opacity(0.6) 聚焦
struct FormTextField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .focused($isFocused)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isFocused ? Color.blue.opacity(0.6) : Color.gray.opacity(0.35),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            )
            .cornerRadius(6)
            .frame(height: 28)
            .frame(width: width)
    }
}

/// 表单区块：标签 + 内容垂直排列，标签到内容间距 6pt
struct FormSection<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FormLabel(text: label)
            content
        }
    }
}

/// 表单卡片容器：统一内边距 12pt、圆角 8pt、可见边框
struct FormCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.18), lineWidth: 0.5)
            )
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
