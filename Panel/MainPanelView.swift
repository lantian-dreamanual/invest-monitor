import SwiftUI
import AppKit

/// 主面板：Tab 切换（黄金 / 板块 / 基金），设置页为独立页面（底部齿轮进入）
struct MainPanelView: View {
    @ObservedObject var controller: MenuBarController
    @State private var tab: Tab = .gold
    @State private var showSettings = false

    enum Tab: String, CaseIterable {
        case gold = "黄金"
        case cpo = "板块"
        case fund = "基金"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if showSettings {
                SettingsView(controller: controller)
            } else {
                content
                if let err = controller.errorMessage {
                    Divider()
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
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 380, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // 顶部标题栏：正常态「投资监控 + 倒计时 + 齿轮」，设置态「设置 + 叉号」
    private var header: some View {
        HStack {
            Text(showSettings ? "设置" : "Dreamanual投资监控")
                .font(.headline)
            Spacer()
            if showSettings {
                Button {
                    showSettings = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("返回")
            } else {
                if controller.allMarketsClosed {
                    Text("已收盘")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if controller.isLoading {
                    Text("刷新中…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(controller.countdown) 秒后更新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
                .help("设置")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // Tab 切换
    private var content: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // 板块页内多板块切换（常驻保留，仅在板块 Tab 时可见可交互）
            if controller.configStore.config.sectors.count > 1 {
                sectorPicker
                    .opacity(tab == .cpo ? 1 : 0)
                    .allowsHitTesting(tab == .cpo)
                    .accessibilityHidden(tab != .cpo)
            }

            // 三个 Tab 常驻保留，切换用 opacity + allowsHitTesting 控制显隐，
            // 避免每次切换销毁重建视图导致的卡顿
            ZStack {
                GoldView(controller: controller)
                    .opacity(tab == .gold ? 1 : 0)
                    .allowsHitTesting(tab == .gold)
                    .accessibilityHidden(tab != .gold)
                SectorView(controller: controller)
                    .opacity(tab == .cpo ? 1 : 0)
                    .allowsHitTesting(tab == .cpo)
                    .accessibilityHidden(tab != .cpo)
                FundView(controller: controller)
                    .opacity(tab == .fund ? 1 : 0)
                    .allowsHitTesting(tab == .fund)
                    .accessibilityHidden(tab != .fund)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    // 板块切换 Picker
    private var sectorPicker: some View {
        Picker("板块", selection: $controller.currentSectorCode) {
            ForEach(controller.configStore.config.sectors, id: \.code) { s in
                Text(s.name).tag(s.code)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: controller.currentSectorCode) { newCode in
            // 方案C：切换板块只刷新当前板块相关数据，不再触发全量 refresh
            Task { await controller.refreshSector(code: newCode) }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }


}

/// 黄金页
struct GoldView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            if let g = controller.gold {
                // 头部
                PriceHeader(
                    title: "沪金主连 (CNY/g)",
                    marketOpen: controller.isGoldMarketOpen,
                    price: String(format: "¥%.2f", g.priceCNY),
                    changePct: g.changePct,
                    secondary: nil
                )

                // 分时图
                if let trend = controller.goldTrendData {
                    TrendChart(trend: trend, mode: .shfeGold)
                        .padding(.horizontal, 16)
                }

                Spacer()
            } else {
                ProgressView("加载中…")
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 信息小格
struct InfoCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}