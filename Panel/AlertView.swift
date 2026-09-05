import SwiftUI
import AppKit

/// 预警规则列表（嵌入设置页卡片内）：按标的分组展示 + 增删 + 组折叠
struct AlertRuleList: View {
    @ObservedObject var controller: MenuBarController
    /// 折叠的组键（持久化）
    @AppStorage("com.dreamanual.investmonitor.CollapsedGroups") private var collapsedGroupsRaw = ""

    private var collapsed: Set<String> {
        Set(collapsedGroupsRaw.split(separator: ",").map(String.init))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 总开关行：全部规则一键启停，样式与单行开关一致
            if !controller.alertConfig.rules.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .frame(width: 18)
                    Text("全部规则")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { !controller.alertConfig.rules.allSatisfy { !$0.enabled } },
                        set: { on in controller.alertConfig.setAllEnabled(on) }
                    ))
                    .toggleStyle(GoldToggleStyle())
                    .labelsHidden()
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(Color.cardBackground)
                Divider().opacity(0.6)
            }

            if controller.alertConfig.rules.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("暂无预警规则，点击 + 添加")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { idx, group in
                        AlertGroupView(
                            group: group,
                            controller: controller,
                            isCollapsed: collapsed.contains(group.id),
                            onToggleCollapse: { toggleCollapse(group.id) }
                        )
                        if idx < groups.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
    }

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
            let key = AlertRuleList.groupKey(r)
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
    let group: AlertRuleList.RuleGroup
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
                        .font(.system(size: 10.5))
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
                        .cornerRadius(6)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.cardBackground)

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
        .background(Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.cardBorder.opacity(allDisabled ? 0.5 : 1), lineWidth: 0.5)
        )
        .opacity(allDisabled ? 0.65 : 1)
    }

    private var groupIcon: String {
        switch group.targetType {
        case .goldCNY: return "scalemass.fill"
        case .sector: return "square.grid.2x2.fill"
        case .fund: return "chart.pie.fill"
        }
    }

    private var groupColor: Color {
        .secondary
    }
}

/// 单条规则行（双行明细）
struct AlertRuleRow: View {
    let rule: AlertRule
    @ObservedObject var controller: MenuBarController
    @State private var showEditSheet = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                // 第一行：方向徽标 + 阈值
                HStack(spacing: 6) {
                    Text(directionText)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .foregroundColor(directionColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
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

            // 开关（品牌金）
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { _ in controller.alertConfig.toggle(rule) }
            ))
            .toggleStyle(GoldToggleStyle())
            .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.panelBackground)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                showEditSheet = true
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                controller.alertConfig.remove(rule)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditAlertSheet(controller: controller, rule: rule, isPresented: $showEditSheet)
        }
    }

    private var directionText: String {
        rule.direction == .above ? "↑ 止盈" : "↓ 止损"
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
            FormSection("标的类型") {
                SegmentedTabs(
                    items: [AlertTargetType.goldCNY, AlertTargetType.sector, AlertTargetType.fund],
                    selection: $targetType,
                    label: { t in
                        switch t {
                        case .goldCNY: return "金CNY"
                        case .sector: return "板块"
                        case .fund: return "基金"
                        }
                    },
                    style: .compact
                )
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
                FormSection("选择标的") {
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
                FormSection("预警基准") {
                    SegmentedTabs(
                        items: FundMetric.allCases,
                        selection: $fundMetric,
                        label: { $0.rawValue },
                        style: .compact
                    )
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
            HStack(spacing: 12) {
                FormSection("方向") {
                    SegmentedTabs(
                        items: [AlertDirection.above, AlertDirection.below],
                        selection: $direction,
                        label: { d in d == .above ? "≥ 涨到" : "≤ 跌到" },
                        style: .compact
                    )
                    .frame(width: 160)
                }
                Spacer()
                FormSection("阈值") {
                    FormTextField(placeholder: thresholdPlaceholder, text: $threshold, width: 100)
                }
            }

            // 动作提示
            FormSection("提醒文案（动作提示）") {
                FormTextField(placeholder: "第1档止盈 · 建议卖1/3", text: $label)
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
                .tint(Color.brandGold)
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

/// 编辑规则弹窗（复用添加弹窗字段，预填当前值）
struct EditAlertSheet: View {
    @ObservedObject var controller: MenuBarController
    let rule: AlertRule
    @Binding var isPresented: Bool

    @State private var targetType: AlertTargetType
    @State private var targetCode: String
    @State private var targetName: String
    @State private var direction: AlertDirection
    @State private var threshold: String
    @State private var label: String
    @State private var fundMetric: FundMetric

    init(controller: MenuBarController, rule: AlertRule, isPresented: Binding<Bool>) {
        self.controller = controller
        self.rule = rule
        self._isPresented = isPresented
        _targetType = State(initialValue: rule.targetType)
        _targetCode = State(initialValue: rule.targetCode)
        _targetName = State(initialValue: rule.targetName)
        _direction = State(initialValue: rule.direction)
        _threshold = State(initialValue: String(format: "%.3f", rule.threshold))
        _label = State(initialValue: rule.label)
        _fundMetric = State(initialValue: rule.fundMetric ?? .nav)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("编辑预警规则")
                .font(.headline)

            // 标的类型
            FormSection("标的类型") {
                SegmentedTabs(
                    items: [AlertTargetType.goldCNY, AlertTargetType.sector, AlertTargetType.fund],
                    selection: $targetType,
                    label: { t in
                        switch t {
                        case .goldCNY: return "金CNY"
                        case .sector: return "板块"
                        case .fund: return "基金"
                        }
                    },
                    style: .compact
                )
                .disabled(true)  // 编辑时不允许改标的类型
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
                FormSection("选择标的") {
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
                FormSection("预警基准") {
                    SegmentedTabs(
                        items: FundMetric.allCases,
                        selection: $fundMetric,
                        label: { $0.rawValue },
                        style: .compact
                    )
                    .onChange(of: fundMetric) { _ in
                        threshold = ""
                    }
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
            HStack(spacing: 12) {
                FormSection("方向") {
                    SegmentedTabs(
                        items: [AlertDirection.above, AlertDirection.below],
                        selection: $direction,
                        label: { d in d == .above ? "≥ 涨到" : "≤ 跌到" },
                        style: .compact
                    )
                    .frame(width: 120)
                }
                Spacer()
                FormSection("阈值") {
                    FormTextField(placeholder: thresholdPlaceholder, text: $threshold, width: 100)
                }
            }

            // 动作提示
            FormSection("提醒文案（动作提示）") {
                FormTextField(placeholder: "第1档止盈 · 建议卖1/3", text: $label)
            }

            Spacer()

            // 按钮
            HStack {
                Spacer()
                Button("取消") { isPresented = false }
                    .buttonStyle(.bordered)
                Button("保存") {
                    saveRule()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGold)
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

    private func saveRule() {
        guard let thr = Double(threshold) else { return }
        var updated = rule
        updated.targetType = targetType
        updated.targetCode = targetCode
        updated.targetName = targetName.isEmpty ? defaultName() : targetName
        updated.direction = direction
        updated.threshold = thr
        updated.label = label
        updated.fundMetric = targetType == .fund ? fundMetric : nil
        controller.alertConfig.update(updated)
    }

    private func defaultName() -> String {
        switch targetType {
        case .goldCNY: return "黄金(CNY/g)"
        case .sector: return "板块"
        case .fund: return "基金"
        }
    }
}