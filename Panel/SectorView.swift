import SwiftUI
import AppKit

/// CPO 板块页：板块指数 + 前 10 大成交额个股
struct SectorView: View {
    @ObservedObject var controller: MenuBarController

    var body: some View {
        VStack(spacing: 0) {
            if let s = controller.sector {
                sectorHeader(s)
            } else {
                ProgressView("加载中…")
                    .frame(height: 90)
            }

            // 分时线图
            if let td = controller.trendData {
                TrendChart(trend: td)
                    .padding(.horizontal, 16)
            }

            Divider()
                .padding(.top, 4)

            if controller.sectorStocks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    ProgressView("加载成分股…")
                    Spacer()
                }
            } else {
                stockHeader
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(controller.sectorStocks.enumerated()), id: \.element.code) { idx, st in
                            StockRow(rank: idx + 1, stock: st)
                            if idx < controller.sectorStocks.count - 1 {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // 板块指数头部
    private func sectorHeader(_ s: SectorQuote) -> some View {
        PriceHeader(
            title: "\(s.name) 板块指数",
            marketOpen: controller.isStockMarketOpen,
            price: Format.price(s.index),
            changePct: s.changePct,
            secondary: "成交额 \(Format.amount(s.amount))"
        )
    }

    private var stockHeader: some View {
        HStack(spacing: 8) {
            Text("#")
                .frame(width: 24, alignment: .leading)
            Text("名称").frame(width: 76, alignment: .leading)
            Spacer()
            Text("现价").frame(width: 58, alignment: .trailing)
            Text("涨跌%").frame(width: 58, alignment: .trailing)
            Text("成交额").frame(width: 60, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }

}

/// 个股行
struct StockRow: View {
    let rank: Int
    let stock: StockQuote

    var body: some View {
        HStack(spacing: 8) {            Text("\(rank)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 24, alignment: .leading)
            Text(stock.name)
                .font(.callout)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)
            Spacer()
            Text(Format.price(stock.price))
                .font(.callout)
                .frame(width: 58, alignment: .trailing)
            Text(Format.pct(stock.changePct))
                .font(.callout)
                .foregroundColor(Color.trend(stock.changePct))
                .frame(width: 58, alignment: .trailing)
            Text(Format.amount(stock.amount))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}