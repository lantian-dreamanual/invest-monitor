#!/bin/bash
# ============================================================
# InvestmentBar 一键打包脚本
# 用法: ./build_dmg.sh
# 流程: 编译 → 组装 app → 签名 → 打包 DMG
# 前置: app 图标/背景图/安装说明已放在 assets/dmg/
# ============================================================

set -e

cd "$(dirname "$0")"

echo "========== 1/4 编译 =========="
xcrun swiftc -O \
  Config/AlertConfig.swift Config/ConfigStore.swift \
  Alert/AlertRule.swift Alert/AlertEngine.swift Alert/AlertNotifier.swift \
  Data/DataLayer.swift Data/FundEstimator.swift \
  Panel/DesignSystem.swift Panel/MainPanelView.swift Panel/SettingsView.swift \
  Panel/AlertView.swift Panel/SectorView.swift Panel/FundView.swift Panel/TrendChart.swift \
  MenuBarController.swift UpdateChecker.swift InvestmentBarApp.swift \
  -o "投资监控" -framework SwiftUI -framework AppKit -parse-as-library
echo "编译成功"

echo "========== 2/4 组装 app =========="
rm -rf "Dreamanual 投资监控.app"
mkdir -p "Dreamanual 投资监控.app/Contents/MacOS"
mkdir -p "Dreamanual 投资监控.app/Contents/Resources/icons"
cp "投资监控" "Dreamanual 投资监控.app/Contents/MacOS/投资监控"
cp Info.plist "Dreamanual 投资监控.app/Contents/Info.plist"
cp "assets/dmg/AppIcon.icns" "Dreamanual 投资监控.app/Contents/Resources/AppIcon.icns"
# 图标 PNG：从 assets/icons/*.svg 转换（若 PNG 已存在直接复制）
if ls assets/icons/*.png &>/dev/null; then
  cp assets/icons/*.png "Dreamanual 投资监控.app/Contents/Resources/icons/"
elif ls assets/icons/*.svg &>/dev/null; then
  swift .temp/convert_icons.swift 2>/dev/null || true
  cp assets/icons/*.png "Dreamanual 投资监控.app/Contents/Resources/icons/" 2>/dev/null || true
fi
echo "app 组装完成"

echo "========== 3/4 签名 =========="
codesign --force --deep --sign - "Dreamanual 投资监控.app"
echo "签名完成"

echo "========== 4/4 打包 DMG =========="
rm -f "dist/Dreamanual 投资监控.dmg"
npx appdmg "assets/dmg/dmg_config.json" "dist/Dreamanual 投资监控.dmg"
echo "DMG 打包完成"

echo "========== 完成 =========="
ls -lh "dist/Dreamanual 投资监控.dmg"
echo ""
echo "可选: 启动新版"
echo "  pkill -f '投资监控'; sleep 1; open 'Dreamanual 投资监控.app'"
