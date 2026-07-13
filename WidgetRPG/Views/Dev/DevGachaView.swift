import SwiftUI

/// 手動プレイ用の観測可能なスカウト状態
@MainActor
final class GachaSimModel: ObservableObject {
    struct DayResult {
        let visitors: [GachaCharacter]
        let picked: GachaCharacter?
        let success: Bool
        let rate: Double
        let skipped: Bool
    }

    @Published var config = GachaConfig()
    @Published var day = 0
    @Published var owned: Set<String> = []
    @Published var fails: [String: Int] = [:]
    @Published var last: DayResult?

    var total: Int { GachaCore.roster.count }
    var isComplete: Bool { owned.count >= total }

    func reset() {
        day = 0; owned = []; fails = [:]; last = nil
    }

    func step() {
        guard !isComplete else { return }
        var rng = SystemRandomNumberGenerator()
        day += 1
        var visitors: [GachaCharacter] = []
        for _ in 0..<config.visitorsPerDay {
            visitors.append(GachaCore.drawVisitor(owned: owned, config: config, using: &rng))
        }
        let candidates = Array(Set(visitors)).filter { !owned.contains($0.id) }
        guard let pick = GachaCore.pick(from: candidates, fails: fails, config: config) else {
            last = DayResult(visitors: visitors, picked: nil, success: false, rate: 0, skipped: true)
            return
        }
        let rate = GachaCore.scoutRate(pick.tier, fails: fails[pick.id] ?? 0, config: config)
        let success = Double.random(in: 0..<1) < rate
        if success { owned.insert(pick.id) } else { fails[pick.id, default: 0] += 1 }
        last = DayResult(visitors: visitors, picked: pick, success: success, rate: rate, skipped: false)
    }

    func step(_ n: Int) { for _ in 0..<n where !isComplete { step() } }
    func finish() { var g = 0; while !isComplete && g < 200_000 { step(); g += 1 } }

    func rate(_ c: GachaCharacter) -> Double {
        GachaCore.scoutRate(c.tier, fails: fails[c.id] ?? 0, config: config)
    }
}

/// 開発用: アプリ内ガチャ(ギルド・スカウト)シミュレーター
struct DevGachaView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = GachaSimModel()

    @State private var stats: GachaStats?
    @State private var computing = false
    @State private var trials = 4000

    private let tiers: [ScoutTier] = [.basic, .special, .rare]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    expectedCard
                    simCard
                    rosterCard
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("ガチャ検証")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.tint(Palette.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if stats == nil { runMonteCarlo() } }
    }

    // MARK: - 期待値

    private var expectedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全16体そろうまで(期待値)")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(stats.map { "\(Int($0.mean.rounded()))" } ?? "…")
                    .font(.system(size: 54, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .monospacedDigit()
                Text("日")
                    .font(.headline)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                if computing { ProgressView().tint(Palette.accent) }
            }
            if let s = stats {
                HStack(spacing: 14) {
                    miniStat("中央値", "\(s.median)日")
                    miniStat("90%", "\(s.p90)日")
                    miniStat("最短〜最長", "\(s.minDay)〜\(s.maxDay)日")
                }
                Text("カテゴリ別にそろう平均: 基本\(Int(s.tierDone[.basic] ?? 0))日 / 特殊\(Int(s.tierDone[.special] ?? 0))日 / レア\(Int(s.tierDone[.rare] ?? 0))日")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack(spacing: 10) {
                Picker("試行", selection: $trials) {
                    Text("2000回").tag(2000)
                    Text("4000回").tag(4000)
                    Text("10000回").tag(10000)
                }
                .pickerStyle(.segmented)
                Button {
                    runMonteCarlo()
                } label: {
                    Text("再計算").font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .disabled(computing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func miniStat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
            Text(v).font(.subheadline.bold()).monospacedDigit().foregroundStyle(Palette.textPrimary)
        }
    }

    // MARK: - 手動シミュレーター

    private var simCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                stat("\(model.day)", "経過日数")
                Spacer()
                stat("\(model.owned.count)/\(model.total)", "仲間")
            }
            ProgressView(value: Double(model.owned.count), total: Double(model.total))
                .tint(Palette.accent)

            drawView

            HStack(spacing: 8) {
                Button("1日") { model.step() }
                    .buttonStyle(.borderedProminent).tint(Palette.accent)
                Button("+10") { model.step(10) }.buttonStyle(.bordered)
                Button("+100") { model.step(100) }.buttonStyle(.bordered)
                Button("集め切る") { model.finish() }.buttonStyle(.bordered)
                Spacer()
                Button(role: .destructive) { model.reset() } label: { Text("リセット") }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline)
            .tint(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func stat(_ n: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(n).font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
            Text(l).font(.system(size: 10)).foregroundStyle(Palette.textSecondary)
        }
    }

    @ViewBuilder
    private var drawView: some View {
        if let last = model.last {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(model.day)日目の来訪者")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 8) {
                    ForEach(Array(Set(last.visitors)), id: \.id) { c in
                        visitorChip(c, last: last)
                    }
                }
                if last.skipped {
                    Text("来訪者は全員すでに仲間。この日は見送り。")
                        .font(.caption).foregroundStyle(Palette.textSecondary)
                } else if let p = last.picked {
                    Text("\(p.name)(\(Int(last.rate * 100))%)をスカウト → ")
                        .font(.caption).foregroundStyle(Palette.textPrimary)
                    + Text(last.success ? "成功!" : "失敗…(次回率アップ)")
                        .font(.caption.bold())
                        .foregroundColor(last.success ? Palette.hpGreen : Palette.danger)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
        } else {
            Text("「1日」でスカウト開始")
                .font(.caption).foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Palette.background))
        }
    }

    private func visitorChip(_ c: GachaCharacter, last: GachaSimModel.DayResult) -> some View {
        let isPick = c.id == last.picked?.id
        let owned = model.owned.contains(c.id) && !isPick
        let color = tierColor(c.tier)
        return VStack(spacing: 2) {
            Text(c.tier.label).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(c.name).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
            Text(isPick ? (last.success ? "成功" : "失敗") : (owned ? "所持" : "\(Int(model.rate(c) * 100))%"))
                .font(.system(size: 10)).monospacedDigit()
                .foregroundStyle(isPick ? (last.success ? Palette.hpGreen : Palette.danger) : Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Palette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isPick ? (last.success ? Palette.hpGreen : Palette.danger) : Palette.panelBorder,
                                lineWidth: isPick ? 1.5 : 1)
                )
        )
        .opacity(owned ? 0.5 : 1)
    }

    // MARK: - ロスター

    private var rosterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tiers) { tier in
                let chars = GachaCore.roster.filter { $0.tier == tier }
                let got = chars.filter { model.owned.contains($0.id) }.count
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Circle().fill(tierColor(tier)).frame(width: 8, height: 8)
                        Text("\(tier.label)キャラ")
                            .font(.caption).foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Text("\(got)/\(chars.count)")
                            .font(.caption.monospaced()).foregroundStyle(Palette.textSecondary)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(chars) { c in charCard(c, tier: tier) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func charCard(_ c: GachaCharacter, tier: ScoutTier) -> some View {
        let owned = model.owned.contains(c.id)
        let f = model.fails[c.id] ?? 0
        return HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(tierColor(tier)).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(owned ? Palette.hpGreen : Palette.textPrimary)
                    .lineLimit(1)
                Text(owned ? "仲間" : "率\(Int(model.rate(c) * 100))%\(f > 0 ? " ・失\(f)" : "")")
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
            if owned { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.hpGreen) }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(owned ? Palette.hpGreen.opacity(0.12) : Palette.background))
    }

    private func tierColor(_ tier: ScoutTier) -> Color {
        switch tier {
        case .basic: Color(red: 0.44, green: 0.58, blue: 0.77)
        case .special: Color(red: 0.34, green: 0.72, blue: 0.65)
        case .rare: Color(red: 0.82, green: 0.55, blue: 0.84)
        }
    }

    // MARK: - モンテカルロ

    private func runMonteCarlo() {
        computing = true
        let config = model.config
        let n = trials
        Task.detached(priority: .userInitiated) {
            let result = GachaStats.compute(config: config, trials: n)
            await MainActor.run {
                stats = result
                computing = false
            }
        }
    }
}

#Preview {
    DevGachaView().preferredColorScheme(.dark)
}
