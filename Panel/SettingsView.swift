import SwiftUI
import AppKit

/// 代码反查状态
enum LookupState {
    case idle
    case loading
    case found(String)
    case notFound

    var isSearching: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// 设置页：自选板块 → 自选基金 → 预警规则（标题在卡片外，对齐 macOS 系统设置风格）
struct SettingsView: View {
    @ObservedObject var controller: MenuBarController
    @State private var newSectorCode = ""
    @State private var sectorLookup: LookupState = .idle
    @State private var lastSearchedSectorCode = ""
    @State private var newFundCode = ""
    @State private var fundLookup: LookupState = .idle
    @State private var lastSearchedFundCode = ""
    @State private var showAddSector = false
    @State private var showAddFund = false
    @State private var showAddAlert = false
    @State private var message: String?
    @State private var showDonation = false
    @State private var donationTab: DonationTab = .wechat

    enum DonationTab: String, CaseIterable {
        case wechat = "微信"
        case alipay = "支付宝"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ===== 自选板块 =====
                VStack(alignment: .leading, spacing: 5) {
                    sectionHeader(
                        title: "自选板块",
                    trailing: IconButton(systemName: showAddSector ? "minus" : "plus") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showAddSector.toggle()
                        }
                    }
                    .help(showAddSector ? "收起" : "添加板块")
                    )

                    SettingsCard {
                        VStack(spacing: 0) {
                            if showAddSector {
                                sectorAddRow
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                Divider().opacity(0.4)
                            }
                            if controller.configStore.config.sectors.isEmpty {
                                Text("暂无板块，点击 + 添加")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(Array(controller.configStore.config.sectors.enumerated()), id: \.element.code) { idx, s in
                                    HStack {
                                        Text(s.name).font(.system(size: 13))
                                        Text(s.code).font(.system(size: 11)).foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            let wasCurrent = (s.code == controller.currentSectorCode)
                                            controller.configStore.removeSector(s)
                                            // 删除的是当前板块：立即切到第一个，不等异步 refresh
                                            if wasCurrent {
                                                controller.currentSectorCode = controller.configStore.config.sectors.first?.code ?? "BK0475"
                                                Task { await controller.refreshSector(code: controller.currentSectorCode) }
                                            } else {
                                                Task { await controller.refresh() }
                                            }
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    if idx < controller.configStore.config.sectors.count - 1 {
                                        Divider().opacity(0.4)
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== 自选基金 =====
                VStack(alignment: .leading, spacing: 5) {
                    sectionHeader(
                        title: "自选基金",
                    trailing: IconButton(systemName: showAddFund ? "minus" : "plus") {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showAddFund.toggle()
                        }
                    }
                    .help(showAddFund ? "收起" : "添加基金")
                    )

                    SettingsCard {
                        VStack(spacing: 0) {
                            if showAddFund {
                                fundAddRow
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                Divider().opacity(0.4)
                            }
                            if controller.configStore.config.funds.isEmpty {
                                Text("暂无基金，点击 + 添加")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            } else {
                                ForEach(Array(controller.configStore.config.funds.enumerated()), id: \.element.code) { idx, f in
                                    HStack {
                                        Text(f.name).font(.system(size: 13))
                                        Text(f.code).font(.system(size: 11)).foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .contentShape(Rectangle())
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            controller.configStore.removeFund(f)
                                            Task { await controller.refresh() }
                                        } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                                    if idx < controller.configStore.config.funds.count - 1 {
                                        Divider().opacity(0.4)
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== 预警规则 =====
                VStack(alignment: .leading, spacing: 5) {
                    sectionHeader(
                        title: "预警规则",
                        trailing: IconButton(systemName: "plus") {
                            showAddAlert = true
                        }
                        .help("添加规则")
                    )

                    SettingsCard {
                        AlertRuleList(controller: controller)
                    }
                }

                // ===== 关于 =====
                VStack(alignment: .leading, spacing: 5) {
                    sectionHeader(title: "关于", trailing: EmptyView())

                    SettingsCard {
                        VStack(spacing: 0) {
                            // 版本号
                            HStack {
                                Text("当前版本")
                                    .font(.system(size: 13))
                                Spacer()
                                Text("v\(controller.updateChecker.currentVersion)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)

                            Divider().opacity(0.4)

                            // 自动检查更新开关
                            HStack {
                                Text("自动检查更新")
                                    .font(.system(size: 13))
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { controller.updateChecker.autoCheckEnabled },
                                    set: { controller.updateChecker.autoCheckEnabled = $0 }
                                ))
                                .labelsHidden()
                                .toggleStyle(GoldToggleStyle())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())

                            Divider().opacity(0.4)

                            // 立即检查
                            HStack {
                                Text("检查最新版本")
                                    .font(.system(size: 13))
                                Spacer()
                                Button("立即检查") {
                                    controller.updateChecker.manualCheck()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                        }
                    }
                }

                // ===== 赞赏 =====
                HStack {
                    Spacer()
                    Button {
                        showDonation.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 11))
                            Text("请我喝杯咖啡")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showDonation, arrowEdge: .bottom) {
                        DonationPopover(tab: $donationTab)
                    }
                }

                if let m = message {
                    Text(m)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showAddAlert) {
            AddAlertSheet(controller: controller, isPresented: $showAddAlert)
        }
    }

    /// 区块标题行：标题在左、操作按钮在右（对齐 macOS 系统设置标题在卡片外的风格）
    private func sectionHeader<Trailing: View>(title: String, trailing: Trailing) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            trailing
        }
    }

    // MARK: - 添加板块

    private func lookupSector() {
        let code = newSectorCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { sectorLookup = .idle; return }
        sectorLookup = .loading
        lastSearchedSectorCode = code
        Task {
            let name = await LookupService.sectorName(code: code)
            await MainActor.run {
                if let name {
                    sectorLookup = .found(name)
                } else {
                    sectorLookup = .notFound
                }
            }
        }
    }

    private func addSector() {
        let code = newSectorCode.trimmingCharacters(in: .whitespaces).uppercased()
        guard !code.isEmpty else { return }
        // 检查重复
        guard !controller.configStore.config.sectors.contains(where: { $0.code == code }) else {
            message = "该板块已添加"
            return
        }
        // 优先用识别到的名称，识别失败则用代码作为名称
        let name: String
        if case let .found(n) = sectorLookup {
            name = n
        } else {
            name = code
        }
        controller.configStore.addSector(SectorConfig(code: code, name: name))
        newSectorCode = ""
        sectorLookup = .idle
        lastSearchedSectorCode = ""
        message = nil
        withAnimation(.easeInOut(duration: 0.15)) { showAddSector = false }
        Task { await controller.refresh() }
    }

    // MARK: - 添加基金

    private func lookupFund() {
        let code = newFundCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { fundLookup = .idle; return }
        fundLookup = .loading
        lastSearchedFundCode = code
        Task {
            let name = await LookupService.fundName(code: code)
            await MainActor.run {
                if let name {
                    fundLookup = .found(name)
                } else {
                    fundLookup = .notFound
                }
            }
        }
    }

    private func addFund() {
        let code = newFundCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        // 检查重复
        guard !controller.configStore.config.funds.contains(where: { $0.code == code }) else {
            message = "该基金已添加"
            return
        }
        let name: String
        if case let .found(n) = fundLookup {
            name = n
        } else {
            name = code
        }
        controller.configStore.addFund(FundConfig(code: code, name: name))
        newFundCode = ""
        fundLookup = .idle
        lastSearchedFundCode = ""
        message = nil
        withAnimation(.easeInOut(duration: 0.15)) { showAddFund = false }
        Task { await controller.refresh() }
    }

    // MARK: - 添加表单行（展开时显示，只输入代码自动识别名称）

    private var sectorAddRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                FormTextField(placeholder: "板块代码 (BK0475)", text: $newSectorCode)
                    .onSubmit { lookupSector() }
                searchButton(
                    code: newSectorCode,
                    lastSearched: lastSearchedSectorCode,
                    isSearching: sectorLookup.isSearching,
                    action: { lookupSector() }
                )
            }
            lookupRow(state: sectorLookup, label: "板块")
        }
    }

    private var fundAddRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                FormTextField(placeholder: "基金代码 (161725)", text: $newFundCode)
                    .onSubmit { lookupFund() }
                searchButton(
                    code: newFundCode,
                    lastSearched: lastSearchedFundCode,
                    isSearching: fundLookup.isSearching,
                    action: { lookupFund() }
                )
            }
            lookupRow(state: fundLookup, label: "基金")
        }
    }

    /// 搜索按钮：与输入框等高（30pt），三种状态循环
    /// - 就绪态（代码未改 / 搜索完成）：无底色 + 主色放大镜
    /// - 待搜索态（代码已改尚未搜索）：主色底 + 深色放大镜
    /// - 搜索中：无底色 + 主色放大镜 + 旋转
    @ViewBuilder
    private func searchButton(code: String, lastSearched: String, isSearching: Bool, action: @escaping () -> Void) -> some View {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        let needsSearch = !trimmed.isEmpty && trimmed.uppercased() != lastSearched.uppercased() && !isSearching
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(needsSearch ? Color(red: 0.13, green: 0.15, blue: 0.16) : Color.brandGold)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(needsSearch ? Color.brandGold : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .disabled(trimmed.isEmpty || isSearching)
        .rotationEffect(isSearching ? .degrees(360) : .zero)
        .animation(isSearching ? .linear(duration: 1).repeatForever(autoreverses: false) : .easeInOut(duration: 0.2), value: isSearching)
        .help("查询名称")
    }
    @ViewBuilder
    private func lookupRow(state: LookupState, label: String) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.small)
                Text("查询中…")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        case .found(let name):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.down)
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    if label == "板块" {
                        addSector()
                    } else {
                        addFund()
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.brandGold)
                .help("添加\(label)")
            }
        case .notFound:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text("未找到该\(label)，请检查代码")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                // 识别失败时仍允许手动添加（用代码作名称）
                Button {
                    if label == "板块" {
                        addSector()
                    } else {
                        addFund()
                    }
                } label: {
                    Text("仍要添加")
                        .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("用代码作为名称添加")
            }
        }
    }
}

// MARK: - 赞赏 Popover

private struct DonationPopover: View {
    @Binding var tab: SettingsView.DonationTab

    var body: some View {
        VStack(spacing: 12) {
            // 分段切换
            HStack(spacing: 0) {
                ForEach(SettingsView.DonationTab.allCases, id: \.self) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tab = t
                        }
                    } label: {
                        Text(t.rawValue)
                            .font(.system(size: 12, weight: tab == t ? .semibold : .regular))
                            .foregroundColor(tab == t ? Color(red: 0.95, green: 0.81, blue: 0.20) : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(tab == t ? Color(red: 0.26, green: 0.21, blue: 0.11) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(red: 0.14, green: 0.16, blue: 0.17))
            )

            // 二维码图片
            Group {
                if let img = loadDonationImage(named: tab == .wechat ? "donation_wechat" : "donation_alipay") {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .cornerRadius(6)
                        .overlay(
                            Text("图片加载失败")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        )
                }
            }

            Text("感谢支持")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 232)
        .background(Color(red: 0.137, green: 0.157, blue: 0.173))
    }

    private func loadDonationImage(named: String) -> NSImage? {
        if let bundlePath = Bundle.main.path(forResource: named, ofType: "png"),
           let img = NSImage(contentsOfFile: bundlePath) {
            return img
        }
        return nil
    }
}
