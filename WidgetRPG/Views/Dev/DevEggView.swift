import SwiftUI

/// 開発用: 卵の孵化シミュレーター。
/// 本番と同じ ItemFactory.hatch() を回して、星・種族・個体値の分布を検証する。
struct DevEggView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var grade: EggGrade = .legendary
    @State private var lastResult: Otomo?
    @State private var tally = Tally()

    /// 集計
    struct Tally {
        var total = 0
        var stars: [Rarity: Int] = [:]
        var legendarySpecies = 0
        var ivTotalSum = 0
        var ivTotalMax = Int.min
        var speciesCount: [String: Int] = [:]

        mutating func add(_ otomo: Otomo) {
            total += 1
            stars[otomo.rarity, default: 0] += 1
            if otomo.species().category == .legendary { legendarySpecies += 1 }
            ivTotalSum += otomo.ivs.total
            ivTotalMax = max(ivTotalMax, otomo.ivs.total)
            speciesCount[otomo.speciesID, default: 0] += 1
        }

        func starRate(_ rarity: Rarity) -> Double {
            total == 0 ? 0 : Double(stars[rarity] ?? 0) / Double(total) * 100
        }

        var legendaryRate: Double {
            total == 0 ? 0 : Double(legendarySpecies) / Double(total) * 100
        }

        var ivAverage: Double {
            total == 0 ? 0 : Double(ivTotalSum) / Double(total)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    gradePicker
                    controls
                    if let lastResult { resultCard(lastResult) }
                    statsCard
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("卵検証")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.tint(Palette.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 卵の選択

    private var gradePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("卵の種類")
                .font(.headline)
                .foregroundStyle(Palette.accent)
            Picker("卵", selection: $grade) {
                ForEach(EggGrade.allCases) { g in
                    Text(g.label).tag(g)
                }
            }
            .pickerStyle(.segmented)
            Text(rateText)
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
        .onChange(of: grade) { _, _ in reset() }
    }

    private var rateText: String {
        let rates = grade.starRates.map { "\($0.rarity.stars) \(format($0.rate))%" }.joined(separator: " / ")
        if grade == .legendary {
            return "設定値: \(rates)(★3のうち\(Int(EggGrade.legendarySpeciesChanceInStar3))%が伝説キャラ)"
        }
        return "設定値: \(rates)"
    }

    // MARK: - 操作

    private var controls: some View {
        HStack(spacing: 8) {
            Button("1回孵化") { hatch(1) }
                .buttonStyle(.borderedProminent).tint(Palette.accent)
            Button("×100") { hatch(100) }.buttonStyle(.bordered)
            Button("×1000") { hatch(1000) }.buttonStyle(.bordered)
            Spacer()
            Button(role: .destructive) { reset() } label: { Text("リセット") }
                .buttonStyle(.bordered)
        }
        .font(.subheadline)
        .tint(Palette.textSecondary)
    }

    private func hatch(_ count: Int) {
        for _ in 0..<count {
            let otomo = ItemFactory.hatch(ItemFactory.makeEgg(grade: grade))
            tally.add(otomo)
            lastResult = otomo
        }
    }

    private func reset() {
        tally = Tally()
        lastResult = nil
    }

    // MARK: - 直近の結果

    private func resultCard(_ otomo: Otomo) -> some View {
        let species = otomo.species()
        return HStack(spacing: 12) {
            CharacterSpriteView(spriteKey: species.id, pixelSize: 3)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(species.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(species.category == .legendary ? Palette.accent : Palette.textPrimary)
                    StarsView(rarity: otomo.rarity)
                    if species.category == .legendary {
                        Text("伝説")
                            .font(.system(size: 9).bold())
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Palette.accent))
                            .foregroundStyle(Palette.background)
                    }
                }
                Text("\(species.category.label) / \(species.element.label)属性")
                    .font(.caption2)
                    .foregroundStyle(Palette.textSecondary)
                Text(ivText(otomo.ivs))
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(otomo.ivs.total >= 10 ? Palette.hpGreen : Palette.textSecondary)
            }
            Spacer()
        }
        .panelStyle()
    }

    private func ivText(_ iv: IndividualValues) -> String {
        func f(_ v: Int) -> String { v >= 0 ? "+\(v)" : "\(v)" }
        return "個体値 HP\(f(iv.hp)) 攻\(f(iv.attack)) 防\(f(iv.defense)) 速\(f(iv.speed)) 魔\(f(iv.magic))(合計\(f(iv.total)))"
    }

    // MARK: - 統計

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("集計")
                    .font(.headline)
                    .foregroundStyle(Palette.accent)
                Spacer()
                Text("\(tally.total)回")
                    .font(.subheadline.bold().monospaced())
                    .foregroundStyle(Palette.textPrimary)
            }

            if tally.total == 0 {
                Text("「1回孵化」または「×100」で回すと分布が出る")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            } else {
                // 星の分布バー
                ForEach(Rarity.allCases, id: \.rawValue) { rarity in
                    starRow(rarity)
                }
                Divider().background(Palette.panelBorder)
                statRow("伝説キャラ排出率",
                        String(format: "%.2f%%(%d体)", tally.legendaryRate, tally.legendarySpecies))
                statRow("個体値合計の平均", String(format: "%+.1f", tally.ivAverage))
                if tally.ivTotalMax > Int.min {
                    statRow("個体値合計の最高", "+\(tally.ivTotalMax)")
                }
                if let best = tally.speciesCount.max(by: { $0.value < $1.value }) {
                    statRow("最多種族", "\(OtomoCatalog.species(id: best.key).name)(\(best.value)体)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelStyle()
    }

    private func starRow(_ rarity: Rarity) -> some View {
        let rate = tally.starRate(rarity)
        return HStack(spacing: 8) {
            Text(rarity.stars)
                .font(.caption2)
                .foregroundStyle(Palette.rarityColor(rarity))
                .frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.background)
                    Capsule()
                        .fill(Palette.rarityColor(rarity))
                        .frame(width: geo.size.width * rate / 100)
                }
            }
            .frame(height: 8)
            Text(String(format: "%.1f%%", rate))
                .font(.caption2.monospaced())
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.bold().monospaced())
                .foregroundStyle(Palette.textPrimary)
        }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}

#Preview {
    DevEggView().preferredColorScheme(.dark)
}
