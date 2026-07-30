import Foundation

/// 特殊戦闘キャラの固有キット。
///
/// 通常キャラのスロットは `Skill` を並べて `BattleSetup.action(from:)` で
/// 戦闘アクションへ変換するが、特殊キャラのギミック(身代わり・行動停止・
/// 遅延ダメージ・ルーレット等)は `Skill` の項目では表現できない。
/// そのため敵の `bossKit(for:)` と同じく **戦闘アクションを直接定義する**。
///
/// 特殊キャラのスロットは職で固定で、**武器スキルによる上書きを受けない**
/// (キット全体でギミックが成立しているため)。
struct SpecialJobKit {
    var slots: [BattleAction]
    var ultimate: BattleAction?
    var ultimateLoops: Int
    var passives: [BattlePassive]
}

enum SpecialJobKits {

    /// 職ID → 固有キット。ここに無い職は通常どおり `Skill` から組み立てる
    static func kit(for jobID: String) -> SpecialJobKit? { all[jobID] }

    static let all: [String: SpecialJobKit] = [

        // MARK: スロットマシン
        // 必殺技を持たない代わりに、開戦時とスロット一巡ごとにルーレットが回る。
        // 効果は4種(攻撃+30% / 味方防御+25% / 追撃付与 / コイン獲得)。
        "slot_machine": SpecialJobKit(
            slots: [
                // メダルアタック: 攻撃力20%を8回。対象は毎回抽選し直す
                BattleAction(name: "メダルアタック",
                             kind: .damage(pct: 20, target: .randomEnemies(1), hits: 8...8)),
                // セブンスラッシュ: 通常77%、5%で777%
                BattleAction(name: "セブンスラッシュ",
                             kind: .jackpot(basePct: 77, bigPct: 777, chance: 5)),
                // レバーオン: 自分の最大HPの20%を回復
                BattleAction(name: "レバーオン",
                             kind: .healPercent(pct: 20, target: .selfUnit)),
            ],
            ultimate: nil, ultimateLoops: 0,
            passives: [.slotMachineRoulette]),

        // MARK: 獣使い
        // オトモを主役にする支援型。パッシブでオトモ全ステータス+40%(BattleSetup 側で加算)。
        "beast_master": SpecialJobKit(
            slots: [
                // 身代わり: 2ターン単体攻撃を集め、味方の被全体攻撃を30%軽減
                BattleAction(name: "身代わり",
                             kind: .taunt(turns: 2, aoeReductionPct: 30)),
                // 回復: 味方全員を攻撃力×100%回復
                BattleAction(name: "回復",
                             kind: .healByAttack(pct: 100, target: .allAllies)),
                // 鼓舞: 味方全員の攻撃を1ターン20%上げ、ランダムな敵1体に180%
                BattleAction(name: "鼓舞",
                             kind: .rally(buffPct: 20, turns: 1, attackPct: 180)),
            ],
            // 群れの咆哮: 場にいるオトモのスキルをランダムに2回発動
            ultimate: BattleAction(name: "群れの咆哮", kind: .triggerOtomoSkills(times: 2)),
            ultimateLoops: 2,
            passives: []),

        // MARK: タイムキーパー
        // 他キャラのスロットに干渉する。パッシブで毎行動、敵全体に10%で行動停止。
        "time_keeper": SpecialJobKit(
            slots: [
                // スキップ: ランダムな味方のスロットを1つ進める
                BattleAction(name: "スキップ", kind: .advanceAllySlot(count: 1)),
                // ディレイ: 敵単体へ攻撃力200%を「次の相手の行動時」に炸裂させる
                BattleAction(name: "ディレイ",
                             kind: .delayedDamage(pct: 200, target: .singleEnemy)),
                // 逆行: 敵単体に50%で逆光(スロットが逆回りする)
                BattleAction(name: "逆行",
                             kind: .inflictAilment(.reverse, chance: 50, target: .singleEnemy)),
            ],
            // 時の楔: 2ターン敵全体を行動停止
            ultimate: BattleAction(name: "時の楔",
                                   kind: .stun(turns: 2, target: .allEnemies, chance: 100)),
            ultimateLoops: 3,
            passives: [.stunAura(chance: 10)]),

        // MARK: ゾンビ
        // 倒れても確率で復活する。復活のたびに復活時HPが10ポイントずつ下がる。
        "zombie": SpecialJobKit(
            slots: [
                BattleAction(name: "噛み付き",
                             kind: .damage(pct: 150, target: .singleEnemy,
                                           inflict: .poison, inflictChance: 70)),
                BattleAction(name: "ウイルス",
                             kind: .inflictAilment(.weakness, chance: 50, target: .allEnemies)),
                BattleAction(name: "再生",
                             kind: .healByAttack(pct: 150, target: .selfUnit)),
            ],
            // 死者の宴: 味方全員に「倒れたらミニゾンビを召喚する」バフを付与
            ultimate: BattleAction(name: "死者の宴", kind: .grantDeathSpawn),
            ultimateLoops: 2,
            passives: [.undying(chance: 50, hpPct: 50, decayPct: 10)]),
    ]
}
