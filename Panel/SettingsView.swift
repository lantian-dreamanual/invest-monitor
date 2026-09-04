import SwiftUI
import AppKit

/// 设置页：自选板块 → 自选基金 → 预警规则（单一滚动页）
struct SettingsView: View {
    @ObservedObject var controller: MenuBarController
    @State private var newSectorCode = ""
    @State private var newSectorName = ""
    @State private var newFundCode = ""
    @State private var newFundName = ""
    @State private var message: String?
    @State private var showAddSector = false
    @State private var showAddFund = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 自选板块（标题右侧 + 展开添加表单）
                sectionHeader("自选板块", showAdd: $showAddSector, helpAdd: "添加板块")
                if showAddSector {
                    sectorAddRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ForEach(controller.configStore.config.sectors, id: \.code) { s in
                    HStack {
                        Text(s.name).font(.callout)
                        Text(s.code).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button {
                            controller.configStore.removeSector(s)
                            Task { await controller.refresh() }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .help("删除板块")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                    )
                }


                Divider()

                // 自选基金（标题右侧 + 展开添加表单）
                sectionHeader("自选基金", showAdd: $showAddFund, helpAdd: "添加基金")
                if showAddFund {
                    fundAddRow
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                ForEach(controller.configStore.config.funds, id: \.code) { f in
                    HStack {
                        Text(f.name).font(.callout)
                        Text(f.code).font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Button {
                            controller.configStore.removeFund(f)
                            Task { await controller.refresh() }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                        .help("删除基金")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                    )
                }


                Divider()

                // 预警规则（嵌入 AlertView）
                AlertView(controller: controller)

                if let m = message {
                    Text(m)
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Text("改动保存到本地，无需重启")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
    }

    /// 小节标题：左侧标题 + 右侧添加/收起按钮
    private func sectionHeader(_ title: String, showAdd: Binding<Bool>, helpAdd: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showAdd.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: showAdd.wrappedValue ? "minus.circle" : "plus.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .help(showAdd.wrappedValue ? "收起" : helpAdd)
        }
    }

    private func addSector() {
        let code = newSectorCode.trimmingCharacters(in: .whitespaces).uppercased()
        let name = newSectorName.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !name.isEmpty else { return }
        controller.configStore.addSector(SectorConfig(code: code, name: name))
        newSectorCode = ""
        newSectorName = ""
        message = nil
        withAnimation(.easeInOut(duration: 0.15)) { showAddSector = false }
        Task { await controller.refresh() }
    }

    private func addFund() {
        let code = newFundCode.trimmingCharacters(in: .whitespaces)
        let name = newFundName.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty, !name.isEmpty else { return }
        controller.configStore.addFund(FundConfig(code: code, name: name))
        newFundCode = ""
        newFundName = ""
        message = nil
        withAnimation(.easeInOut(duration: 0.15)) { showAddFund = false }
        Task { await controller.refresh() }
    }

    // MARK: - 添加表单行（展开时显示）

    private var sectorAddRow: some View {
        HStack(spacing: 8) {
            FormTextField(placeholder: "代码 (BK0475)", text: $newSectorCode)
                .onSubmit { addSector() }
            FormTextField(placeholder: "名称 (半导体)", text: $newSectorName)
                .onSubmit { addSector() }
            Button {
                addSector()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(newSectorCode.isEmpty || newSectorName.isEmpty)
            .help("添加板块")
        }
    }

    private var fundAddRow: some View {
        HStack(spacing: 8) {
            FormTextField(placeholder: "代码 (161725)", text: $newFundCode)
                .onSubmit { addFund() }
            FormTextField(placeholder: "名称 (招商中证白酒指数C)", text: $newFundName)
                .onSubmit { addFund() }
            Button {
                addFund()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(newFundCode.isEmpty || newFundName.isEmpty)
            .help("添加基金")
        }
    }
}