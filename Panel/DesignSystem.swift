import SwiftUI

// ============ 设计系统：共享组件 ============

/// 品牌主色：金色（对齐 App 图标 #E9B832），金融产品深色+金色格调
extension Color {
    static let brandGold = Color(red: 0.914, green: 0.722, blue: 0.196)  // #E9B832
    static let brandGoldBright = Color(red: 0.957, green: 0.812, blue: 0.349)  // #F4CF59 亮金（选中态文字）
    static let brandGoldDim = Color(red: 0.914, green: 0.722, blue: 0.196).opacity(0.6)  // 聚焦弱化
    /// 选中态深色底：金调深褐 #42351C，与金色系统一
    static let brandSelectedBG = Color(red: 0.259, green: 0.208, blue: 0.110)  // #42351C
}

/// 配色：Pillow 像素级取色自 macOS 系统设置深色模式截图
/// 面板底 #23282C / 卡片底 #2A2F32 / 斑马纹浅行 #35393C / 斑马纹深行 #2A2F32
extension Color {
    /// 面板底色 #23282C
    static let panelBackground = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil {
            return NSColor(srgbRed: 0.137, green: 0.157, blue: 0.173, alpha: 1)
        } else {
            return NSColor.windowBackgroundColor
        }
    })
    /// 卡片底色 #2A2F32
    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        if appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil {
            return NSColor(srgbRed: 0.165, green: 0.184, blue: 0.196, alpha: 1)
        } else {
            return NSColor.controlBackgroundColor
        }
    })
    /// 斑马纹浅行 #35393C
    static let zebraLight = Color(red: 0.208, green: 0.224, blue: 0.235)
    /// 斑马纹深行 #2A2F32（同卡片底）
    static let zebraDark = Color(red: 0.165, green: 0.184, blue: 0.196)
    /// 卡片描边 #36383C
    static let cardBorder = Color(red: 0.212, green: 0.220, blue: 0.235)
}

/// 交易状态
enum MarketStatus: Equatable {
    case trading   // 交易中
    case break_    // 午休
    case closed    // 已收盘
}

/// 交易状态标签
struct MarketStatusBadge: View {
    let status: MarketStatus

    private var text: String {
        switch status {
        case .trading: return "交易中"
        case .break_: return "午休"
        case .closed: return "已收盘"
        }
    }

    private var isTrading: Bool { status == .trading }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(isTrading ? Color.brandGold.opacity(0.15) : Color.panelBackground)
            .foregroundColor(isTrading ? .brandGold : .secondary.opacity(0.55))
            .cornerRadius(6)
    }
}

// ============ 设计系统：分段控件 ============

/// 自定义分段控件：对齐 macOS Tahoe 系统设置样式
/// 选中态 = 品牌金色填充 + 白字；未选中 = 透明 + 次要色文字
/// 解决 nonactivatingPanel 下系统分段控件选中态变灰的问题
struct SegmentedTabs<T: Hashable>: View {
    let items: [T]
    @Binding var selection: T
    var label: (T) -> String
    var style: Style = .default

    enum Style {
        case `default`      // 主 Tab：通栏等宽
        case compact        // 表单内：跟随内容宽度
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { idx, item in
                let selected = item == selection
                let isLast = idx == items.count - 1
                Button {
                    selection = item
                } label: {
                    Text(label(item))
                        .font(.system(size: 12, weight: selected ? .medium : .regular))
                        .foregroundColor(selected ? Color.brandGoldBright : .secondary)
                        .lineLimit(1)
                        .padding(.horizontal, style == .default ? 16 : 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.zebraLight)
                                .opacity(selected ? 1 : 0)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.zebraLight, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

// ============ 设计系统：图标按钮 ============

/// 带悬浮反馈的图标按钮：解决 nonactivatingPanel 下 .borderless/.plain 无悬浮态问题
/// 悬浮时背景变亮 + 图标颜色提亮，让用户感知可点击
struct IconButton: View {
    let systemName: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isHovered ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// ============ 设计系统：品牌开关 ============

/// 金色开关：对齐 macOS 系统开关形态（胶囊轨道 + 滑块），开启态用品牌金 + 深色滑块
struct GoldToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            RoundedRectangle(cornerRadius: 9.5, style: .continuous)
                .fill(configuration.isOn ? Color.brandGold : Color.secondary.opacity(0.3))
                .frame(width: 32, height: 19)
                .overlay(
                    GeometryReader { geo in
                        Circle()
                            .fill(configuration.isOn ? Color(red: 0.13, green: 0.15, blue: 0.16) : Color.white)
                            .frame(width: 13, height: 13)
                            .offset(
                                x: configuration.isOn ? geo.size.width - 15 : 2,
                                y: (geo.size.height - 13) / 2
                            )
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
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
/// - 高度 28pt，圆角 6pt，底色对齐分段导航选中态 zebraLight，边框 cardBorder 常态 / 金色聚焦
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
            .padding(.vertical, 5)
            .background(Color.zebraLight)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isFocused ? Color.brandGold.opacity(0.7) : Color.cardBorder,
                        lineWidth: isFocused ? 1.5 : 0.5
                    )
            )
            .cornerRadius(6)
            .frame(height: 30)
            .frame(width: width)
    }
}

/// 表单区块：标签 + 内容垂直排列，标签到内容间距 8pt
struct FormSection<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormLabel(text: label)
            content
        }
    }
}

/// 表单卡片容器：统一内边距 14pt、圆角 10pt、可见边框
struct FormCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
    }
}

/// 行情卡片容器：圆角12、边框0.10、内边距14，对齐 macOS Tahoe 内容卡片风格
struct MarketCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
    }
}

/// 设置页卡片：内容区，对齐 macOS Tahoe 系统设置列表风格（标题在卡片外）
struct SettingsCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cardBorder, lineWidth: 0.5)
            )
    }
}

/// 统一行情头部：标签 + 状态 → 大价格 → 涨跌 + 次要信息
struct PriceHeader: View {
    let title: String
    let marketStatus: MarketStatus?      // nil = 不显示状态标签
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
                if let status = marketStatus {
                    MarketStatusBadge(status: status)
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
        .frame(maxWidth: .infinity)
    }
}
