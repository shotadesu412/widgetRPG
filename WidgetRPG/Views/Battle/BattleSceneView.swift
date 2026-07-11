import SwiftUI

/// ATB戦闘の共通シーン(通常ボス戦と開発用の調整ステージで共用)。
/// 左に味方、右に敵を表示。ゲージはメモリ無しの緑→赤グラデーション。
struct BattleSceneView: View {
    @ObservedObject var engine: BattleEngine
    let title: String
    /// 戦闘を離脱(逃げる・閉じる)
    var onExit: () -> Void
    /// 決着後の続行ボタン。結果を渡す
    var onFinish: (BattleEngine.BattleResult) -> Void
    /// 決着後ボタンのラベル(勝敗別)
    var finishLabel: (BattleEngine.BattleResult) -> String = { $0 == .victory ? "戦利品を持ち帰る" : "拠点に戻る" }
    /// 調整用の「もう一度」など追加操作
    var extraResultButton: (label: String, action: () -> Void)?

    @State private var running = true
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    ForEach(engine.allies) { unit in
                        BattleUnitView(unit: unit, alignLeft: true)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    ForEach(engine.enemies) { unit in
                        BattleUnitView(unit: unit, alignLeft: false)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()

            battleLog
            resultFooter
        }
        .background(Palette.background)
        .onReceive(timer) { _ in
            guard running, engine.result == nil else { return }
            engine.tick(deltaTime: 0.05)
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.accent)
            Spacer()
            if engine.result == nil {
                Button("逃げる") { onExit() }
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding()
        .background(Palette.panel)
    }

    private var battleLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(engine.log.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(line.contains("毒") ? Palette.poison : Palette.textSecondary)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            .frame(height: 150)
            .onChange(of: engine.log.count) { _, count in
                withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private var resultFooter: some View {
        if let result = engine.result {
            VStack(spacing: 10) {
                Text(result == .victory ? "勝利!!" : "敗北……")
                    .font(.title2.bold())
                    .foregroundStyle(result == .victory ? Palette.accent : Palette.danger)
                HStack(spacing: 10) {
                    if let extra = extraResultButton {
                        Button(extra.label, action: extra.action)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Palette.panelBorder))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Button {
                        onFinish(result)
                    } label: {
                        Text(finishLabel(result))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.panel))
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
            .padding()
        } else {
            Color.clear.frame(height: 12)
        }
    }
}

/// 戦闘中のユニット表示(HPバー・ATBゲージ・スロット状況・毒表示)
struct BattleUnitView: View {
    let unit: BattleEngine.Unit
    let alignLeft: Bool

    var body: some View {
        VStack(alignment: alignLeft ? .leading : .trailing, spacing: 4) {
            HStack {
                if alignLeft {
                    sprite
                    info
                } else {
                    info
                    sprite
                }
            }

            hpBar
            atbBar
            if unit.isAlly { slotRow }
            // 行動ごとにキャラの下へスキル名を表示(高さは固定して揺れを防ぐ)
            actionLabel
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Palette.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Palette.poison, lineWidth: unit.poisoned ? 1.5 : 0)
                )
        )
        .opacity(unit.isAlive ? 1.0 : 0.35)
        // 被弾・回復の数値をキャラの上に浮かべる
        .overlay(alignment: .top) { floatingNumber }
    }

    @ViewBuilder
    private var actionLabel: some View {
        Text(unit.actionLabel ?? " ")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Palette.accent)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .opacity(unit.actionLabel == nil ? 0 : 1)
    }

    @ViewBuilder
    private var floatingNumber: some View {
        if let f = unit.floating {
            let progress = f.age / f.life
            Text(text(for: f))
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(color(for: f.kind))
                .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                .offset(y: -14 - CGFloat(progress) * 26)
                .opacity(1.0 - progress)
        }
    }

    private func text(for f: FloatingNumber) -> String {
        f.kind == .heal ? "+\(f.value)" : "\(f.value)"
    }

    private func color(for kind: FloatingNumber.Kind) -> Color {
        switch kind {
        case .damage: .white
        case .heal: Palette.hpGreen
        case .poison: Palette.poison
        }
    }

    private var sprite: some View {
        CharacterSpriteView(spriteKey: unit.spriteKey, state: unit.visualState,
                            pixelSize: 4, flipped: !alignLeft)
            .animation(.easeInOut(duration: 0.12), value: unit.visualState)
            // 毒のときは紫に染める
            .overlay {
                if unit.poisoned {
                    Palette.poison.opacity(0.45).blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
            }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(unit.name)
                .font(.caption.bold())
                .foregroundStyle(unit.hasAilment ? Palette.poison : Palette.textPrimary)
                .lineLimit(1)
            // 状態異常バッジ(毒・洗脳・火傷・逆光・弱体化・攻撃低下・速度低下)
            if unit.hasAilment {
                HStack(spacing: 2) {
                    ForEach(unit.ailmentList, id: \.self) { ailment in
                        Text(ailment.label)
                            .font(.system(size: 7).bold())
                            .padding(.horizontal, 3).padding(.vertical, 1)
                            .background(Capsule().fill(badgeColor(ailment)))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
            }
            Text("HP \(unit.hp)/\(unit.maxHP)")
                .font(.system(size: 9))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func badgeColor(_ ailment: Ailment) -> Color {
        switch ailment {
        case .poison: Palette.poison
        case .burn: Palette.danger
        case .brainwash: Color(red: 0.85, green: 0.45, blue: 0.65)
        case .reverse: Color(red: 0.40, green: 0.55, blue: 0.85)
        case .weakness, .attackDown, .speedDown: Color(white: 0.45)
        }
    }

    private var hpBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.background)
                Capsule()
                    .fill(unit.poisoned ? Palette.poison : Palette.hpGreen)
                    .frame(width: geo.size.width * CGFloat(unit.hp) / CGFloat(max(unit.maxHP, 1)))
            }
        }
        .frame(height: 5)
    }

    private var atbBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.background)
                Capsule()
                    .fill(Palette.atbColor(progress: unit.gauge))
                    .frame(width: geo.size.width * CGFloat(min(unit.gauge, 1.0)))
            }
        }
        .frame(height: 4)
    }

    private var slotRow: some View {
        HStack(spacing: 3) {
            ForEach(unit.slots.indices, id: \.self) { index in
                Circle()
                    .fill(index == unit.slotIndex ? Palette.accent : Palette.panelBorder)
                    .frame(width: 6, height: 6)
            }
            if unit.ultimate != nil {
                Text("必殺 \(unit.loops)/\(unit.ultimateLoops)")
                    .font(.system(size: 8))
                    .foregroundStyle(unit.ultimateReady ? Palette.danger : Palette.textSecondary)
            }
        }
    }
}
