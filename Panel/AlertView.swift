import SwiftUI
import AppKit

/// 预警管理区块（嵌入设置页）：按标的分组展示 + 增删 + 暂停恢复 + 组折叠
struct AlertView: View {
    @ObservedObject var controller: MenuBarController
    @State private var showAddSheet = false
    @State private var allPaused = false
    /// 折叠的组键（持久化）
    @AppStorage("com.dreamanual.investmonitor.CollapsedGroups") private var collapsedGroupsRaw = ""

    private var collapsed: Set<String> {
        Set(collapsedGroupsRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 区块操作行：标题 + 暂停/恢复 + 添加
            HStack {
                Text("预警规则")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button(allPaused ? "全部恢复" : "全部暂停") {
                    allPaused.toggle()
                    controller.alertConfig.setAllEnabled(!allPaused)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(controller.alertConfig.rules.isEmpty)

                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("添加规则")
            }

            if controller.alertConfig.rules.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("暂无预警规则，点击 + 添加")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups) { group in
                        AlertGroupView(
                            group: group,
                            controller: controller,
                            isCollapsed: collapsed.contains(group.id),
                            onToggleCollapse: { toggleCollapse(group.id) }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showAddSheet) {
            AddAlertSheet(controller: controller, isPresented: $showAddSheet)
        }
        .onAppear {
            allPaused = controller.alertConfig.rules.allSatisfy { !$0.enabled }
        }
    }

    private var allTitles: String { allPaused ? "全部恢复" : "全部暂停" }

    // MARK: - 分组

    struct RuleGroup: Identifiable {
        let id: String
        let targetType: AlertTargetType
        let name: String
        let rules: [AlertRule]
    }

    private var groups: [RuleGroup] {
        var order: [String] = []
        var dict: [String: [AlertRule]] = [:]
        for r in controller.alertConfig.rules {
            let key = AlertView.groupKey(r)
            if dict[key] == nil { order.append(key) }
            dict[key, default: []].append(r)
        }
        return order.map { key in
            let rules = dict[key]!
            let first = rules[0]
            return RuleGroup(id: key, targetType: first.targetType, name: first.targetName, rules: rules)
        }
    }

    private static func groupKey(_ r: AlertRule) -> String {
        "\(r.targetType.rawValue)|\(r.targetCode)"
    }

    private func toggleCollapse(_ id: String) {
        var set = collapsed
        if set.contains(id) { set.remove(id) } else { set.insert(id) }
        collapsedGroupsRaw = set.sorted().joined(separator: ",")
    }
}

/// 标的分组：组头（图标 + 标的名 + 条数 + 折叠） + 组内规则行
struct AlertGroupView: View {
    let group: AlertView.RuleGroup
    @ObservedObject var controller: MenuBarController
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void

    private var hasTriggered: Bool { group.rules.contains { $0.triggered && $0.enabled } }
    private var allDisabled: Bool { group.rules.allSatisfy { !$0.enabled } }

    var body: some View {
        VStack(spacing: 0) {
            // 组头
            Button(action: onToggleCollapse) {
                HStack(spacing: 6) {
                    Image(systemName: groupIcon)
                        .font(.system(size: 12))
                        .foregroundColor(groupColor)
                        .frame(width: 18)
                    Text(group.name)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text("\(group.rules.count) 条")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(hasTriggered ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.12))
                        .foregroundColor(hasTriggered ? .orange : .secondary)
                        .cornerRadius(999)
                    Spacer()
                    Text(groupUnit)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .buttonStyle(.plain)
            .disabled(false)

            // 组内规则
            if !isCollapsed {
                Divider().opacity(0.6)
                VStack(spacing: 0) {
                    ForEach(Array(group.rules.enumerated()), id: \.element.id) { idx, rule in
                        AlertRuleRow(rule: rule, controller: controller)
                        if idx < group.rules.count - 1 {
                            Divider().opacity(0.4).padding(.leading, 26)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(allDisabled ? 0.1 : 0.18), lineWidth: 0.5)
        )
        .opacity(allDisabled ? 0.65 : 1)
    }

    private var groupIcon: String {
        switch group.targetType {
        case .goldCNY: return "dollarsign.circle.fill"
        case .sector: return "chart.line.uptrend.xyaxis"
        case .fund: return "chart.pie.fill"
        }
    }

    private var groupColor: Color {
        switch group.targetType {
        case .goldCNY: return .orange
        case .sector: return .blue
        case .fund: return .purple
        }
    }

    private var groupUnit: String {
        switch group.targetType {
        case .goldCNY: return "¥/克"
        case .sector: return "%"
        case .fund:
            // 基金组按第一条规则基准显示单位
            if group.rules.first?.fundMetric == .changePct {
                return "基金 · %"
            }
            return "基金 · 净值"
        }
    }
}

/// 单条规则行（双行明细）
struct AlertRuleRow: View {
    let rule: AlertRule
    @ObservedObject var controller: MenuBarController

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 状态点
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .padding(.top, 9)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.25), lineWidth: 3)
                        .frame(width: 12, height: 12)
                        .padding(.top, 9)
                )

            VStack(alignment: .leading, spacing: 3) {
                // 第一行：方向徽标 + 阈值
                HStack(spacing: 6) {
                    Text(directionText)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .foregroundColor(directionColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(directionColor.opacity(0.45), lineWidth: 0.8)
                        )
                    Text(formatThreshold(rule))
                        .font(.callout)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundColor(rule.enabled ? .primary : .secondary)
                }

                // 第二行：动作提示 / 触发状态
                HStack(spacing: 4) {
                    if rule.triggered, let t = rule.triggeredAt {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("已触发 \(t, format: .dateTime.hour().minute())")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Text(rule.label)
                            .font(.caption2)
                            .foregroundColor(rule.enabled ? .secondary : .secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            // 开关
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in controller.alertConfig.toggle(rule) }
            ))
            .labelsHidden()
            .controlSize(.mini)
            .padding(.top, 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .contextMenu {
            Button(role: .destructive) {
                controller.alertConfig.remove(rule)
            } label: {
                Label("删除此规则", systemImage: "trash")
            }
        }
    }

    private var directionText: String {
        rule.direction == .above ? "↑ 止盈" : "↓ 止损"
    }

    private var statusColor: Color {
        if !rule.enabled { return .gray }
        if rule.triggered { return .orange }
        return .green
    }

    private var directionColor: Color {
        rule.direction == .above ? .red : .green
    }

    private func formatThreshold(_ r: AlertRule) -> String {
        switch r.targetType {
        case .goldCNY:
            return String(format: "%.2f", r.threshold)
        case .sector:
            return String(format: "%.2f%%", r.threshold)
        case .fund:
            // 净值模式显示价位，涨跌幅模式显示百分比
            if r.fundMetric == .changePct {
                return String(format: "%.2f%%", r.threshold)
            }
            return String(format: "%.3f", r.threshold)
        }
    }
}

/// 添加规则弹窗
struct AddAlertSheet: View {
    @ObservedObject var controller: MenuBarController
    @Binding var isPresented: Bool

    @State private var targetType: AlertTargetType = .goldCNY
    @State private var targetCode = ""
    @State private var targetName = "黄金(CNY/g)"
    @State private var direction: AlertDirection = .above
    @State private var threshold = ""
    @State private var label = ""
    @State private var fundMetric: FundMetric = .nav

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("添加预警规则")
                .font(.headline)

            // 标的类型
            VStack(alignment: .leading, spacing: 4) {
                Text("标的类型").font(.caption).foregroundColor(.secondary)
                Picker("", selection: $targetType) {
                    Text("金CNY").tag(AlertTargetType.goldCNY)
                    Text("板块").tag(AlertTargetType.sector)
                    Text("基金").tag(AlertTargetType.fund)
                }
                .pickerStyle(.segmented)
                .onChange(of: targetType) { newType in
                    switch newType {
                    case .goldCNY: targetName = "黄金(CNY/g)"; targetCode = ""
                    case .sector:
                        targetName = ""
                        targetCode = controller.configStore.config.sectors.first?.code ?? ""
                    case .fund:
                        targetName = ""
                        targetCode = controller.configStore.config.funds.first?.code ?? ""
                    }
                }
            }

            // 板块/基金选择
            if targetType == .sector || targetType == .fund {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择标的").font(.caption).foregroundColor(.secondary)
                    if targetType == .sector {
                        Picker("", selection: $targetCode) {
                            ForEach(controller.configStore.config.sectors, id: \.code) { s in
                                Text("\(s.name) (\(s.code))").tag(s.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: targetCode) { newCode in
                            targetName = controller.configStore.config.sectors.first(where: { $0.code == newCode })?.name ?? ""
                        }
                    } else {
                        Picker("", selection: $targetCode) {
                            ForEach(controller.configStore.config.funds, id: \.code) { f in
                                Text("\(f.name) (\(f.code))").tag(f.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: targetCode) { newCode in
                            targetName = controller.configStore.config.funds.first(where: { $0.code == newCode })?.name ?? ""
                        }
                    }
                }
            }

            // 基金预警基准（仅基金）
            if targetType == .fund {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预警基准").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $fundMetric) {
                        ForEach(FundMetric.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: fundMetric) { _ in
                        threshold = ""
                    }
                    // 提示：基金预警只通过官方净值触发
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("基金预警在净值更新后触发（每个交易日收盘后）")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 方向 + 阈值
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("方向").font(.caption).foregroundColor(.secondary)
                    Picker("", selection: $direction) {
                        Text("≥ 涨到").tag(AlertDirection.above)
                        Text("≤ 跌到").tag(AlertDirection.below)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("阈值").font(.caption).foregroundColor(.secondary)
                    TextField(thresholdPlaceholder, text: $threshold)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }

            // 动作提示
            VStack(alignment: .leading, spacing: 4) {
                Text("提醒文案（动作提示）").font(.caption).foregroundColor(.secondary)
                TextField("第1档止盈 · 建议卖1/3", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            Spacer()

            // 按钮
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .buttonStyle(.bordered)
                Button("添加") {
                    addRule()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(threshold.isEmpty || label.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 360, height: 440)
        .fixedSize(horizontal: false, vertical: true)
    }



    private var thresholdPlaceholder: String {
        if targetType == .goldCNY { return "700.00" }
        if targetType == .fund && fundMetric == .nav { return "1.50" }
        return "-2.50"
    }

    private func addRule() {
        guard let thr = Double(threshold) else { return }
        let rule = AlertRule(
            id: UUID().uuidString,
            targetType: targetType,
            targetCode: targetCode,
            targetName: targetName.isEmpty ? defaultName() : targetName,
            direction: direction,
            threshold: thr,
            label: label,
            enabled: true,
            triggered: false,
            triggeredAt: nil,
            fundMetric: targetType == .fund ? fundMetric : nil
        )
        controller.alertConfig.add(rule)
    }

    private func defaultName() -> String {
        switch targetType {
        case .goldCNY: return "黄金(CNY/g)"
        case .sector: return "板块"
        case .fund: return "基金"
        }
    }

}