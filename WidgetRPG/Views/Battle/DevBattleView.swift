import SwiftUI

/// 開発用の戦闘バランス調整ステージ。
/// 戦う味方を選んでから ヒュドラ(中盤ボス)戦を再現する。
/// 数値やスキルは Shared/Core/BattleEngine.swift で調整する。
struct DevBattleView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = BattleEngine()

    @State private var selected: Set<String> = ["swordsman", "spider", "octopus"]
    /// 敵(ヒュドラ)の属性。属性相性の検証用に切り替えられる
    @State private var enemyElement: Element = .dark
    @State private var inBattle = false

    private let roster = BattleEngine.balanceRoster

    var body: some View {
        Group {
            if inBattle {
                BattleSceneView(
                    engine: engine,
                    title: "調整用ステージ: ヒュドラ戦",
                    onExit: { inBattle = false },
                    onFinish: { _ in inBattle = false },
                    finishLabel: { _ in "編成に戻る" },
                    extraResultButton: (label: "同じ編成で再戦", action: startBattle)
                )
            } else {
                selection
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 開発用: DEV_BATTLE_AUTO="akuma,swordsman" 等で編成を指定して即開始。
            // DEV_BATTLE_ELEM で敵属性も指定できる(fire/water/electric/dark/wind)
            if let a = ProcessInfo.processInfo.environment["DEV_BATTLE_AUTO"], !inBattle {
                selected = Set(a.split(separator: ",").map(String.init))
                if let e = ProcessInfo.processInfo.environment["DEV_BATTLE_ELEM"],
                   let element = Element(rawValue: e) {
                    enemyElement = element
                }
                startBattle()
            }
        }
    }

    // MARK: - 編成選択

    private var selection: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("戦う味方を選ぶ")
                        .font(.headline)
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(roster) { ally in
                        allyRow(ally)
                    }

                    enemyCard

                    Button(action: startBattle) {
                        Text(selected.isEmpty ? "味方を1体以上選ぶ" : "戦闘開始")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(selected.isEmpty ? Palette.panel : Palette.danger))
                            .foregroundStyle(selected.isEmpty ? Palette.textSecondary : .white)
                    }
                    .disabled(selected.isEmpty)
                }
                .padding()
            }
            .background(Palette.background)
            .navigationTitle("戦闘バランス調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }.tint(Palette.accent)
                }
            }
        }
    }

    private func allyRow(_ ally: BattleEngine.BalanceAlly) -> some View {
        let on = selected.contains(ally.id)
        let unit = ally.make()
        return Button {
            if on { selected.remove(ally.id) } else { selected.insert(ally.id) }
        } label: {
            HStack(spacing: 12) {
                CharacterSpriteView(spriteKey: ally.spriteKey, pixelSize: 4, height: 52)
                    .frame(width: 52)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(ally.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(Palette.textPrimary)
                        Image(systemName: ally.element.symbolName)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.elementColor(ally.element))
                    }
                    Text("HP\(unit.maxHP) 攻\(unit.attack) 防\(unit.defense) 速\(unit.speed) 魔\(unit.magic) ・ スロット\(unit.slots.count)")
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(Palette.textSecondary)
                    Text(unit.slots.map(\.name).joined(separator: " / "))
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Palette.accent : Palette.textSecondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Palette.panel)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(on ? Palette.accent : Palette.panelBorder, lineWidth: on ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var enemyCard: some View {
        let hydra = BattleEngine.balanceHydra(element: enemyElement)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(Palette.danger)
                    .frame(width: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("VS  \(hydra.name)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.danger)
                    Text("HP\(hydra.maxHP) 攻\(hydra.attack) 防\(hydra.defense)(戦闘では無効) 速\(hydra.speed) 魔\(hydra.magic)")
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            // 属性相性の検証用: 敵の属性を切り替える
            Picker("敵の属性", selection: $enemyElement) {
                ForEach(Element.allCases) { element in
                    Text(element.label).tag(element)
                }
            }
            .pickerStyle(.segmented)
            Text("相性: 風→電気→水→炎→風(有利1.3倍/不利0.85倍)。闇は与ダメ・被ダメとも1.2倍")
                .font(.system(size: 9))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.panel))
    }

    private func startBattle() {
        guard !selected.isEmpty else { return }
        // 選択順を roster 順に整える
        let ids = roster.map(\.id).filter { selected.contains($0) }
        let fresh = BattleEngine.makeBalanceStage(allyIDs: ids, enemyElement: enemyElement)
        engine.allies = fresh.allies
        engine.enemies = fresh.enemies
        engine.log = fresh.log
        engine.result = nil
        inBattle = true
    }
}

#Preview {
    DevBattleView().preferredColorScheme(.dark)
}
