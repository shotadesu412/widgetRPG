import Foundation

/// キャラクターの成長イベント(習得レベル・進化)の一元管理。
///
/// 習得テーブル:
///   Lv10 スキル / Lv25 進化(第一必殺技) / Lv30 パッシブ /
///   Lv45 進化(第二必殺技) / Lv60 パッシブ / Lv70 スキル / Lv80 パッシブ
enum CharacterProgression {

    /// 進化可能になるレベル(第一進化 / 第二進化)
    static let evolutionLevels = [25, 45]
    /// スキルを自動習得するレベル
    static let skillLevels = [10, 70]
    /// パッシブを自動習得するレベル
    static let passiveLevels = [30, 60, 80]

    /// 次の進化に必要なレベル(進化しきっていれば nil)
    static func requiredEvolutionLevel(forStage stage: Int) -> Int? {
        stage < evolutionLevels.count ? evolutionLevels[stage] : nil
    }

    /// 次にレベルで習得できるもの(UI表示用)。例: (30, "パッシブ")
    static func nextLevelReward(after level: Int) -> (level: Int, label: String)? {
        let all = skillLevels.map { ($0, "スキル") }
            + passiveLevels.map { ($0, "パッシブ") }
            + evolutionLevels.map { ($0, "進化") }
        return all.filter { $0.0 > level }.min { $0.0 < $1.0 }
    }

    /// レベル到達時の自動習得(レベルアップ1ごとに呼ぶ)。
    /// スキルはジョブプール(未定義なら共通プール)から抽選し、空きスロットへ自動配置。
    /// パッシブはジョブのパッシブプール(未定義なら共通プール)から抽選
    static func grantLevelRewards(_ chara: inout PlayerCharacter, reachedLevel: Int) {
        let job = chara.job()

        if skillLevels.contains(reachedLevel) {
            let pool = SkillCatalog.jobSkills[job.id].flatMap { $0.isEmpty ? nil : $0 }
                ?? SkillCatalog.jobDefaultSkills
            if let entry = SkillCatalog.draw(from: pool) {
                let skill = entry.make(element: job.element)
                chara.learnedSkills.append(skill)
                if let slot = chara.placedSkills.firstIndex(where: { $0 == nil }) {
                    chara.placedSkills[slot] = skill
                }
            }
        }

        if passiveLevels.contains(reachedLevel) {
            let pool = SkillCatalog.jobPassives[job.id].flatMap { $0.isEmpty ? nil : $0 }
                ?? SkillCatalog.characterPassives
            if let entry = SkillCatalog.draw(from: pool) {
                chara.passives.append(entry.make())
            }
        }
    }

    /// 進化する。属性石を1個消費し、必殺技を習得する
    /// (第一進化=第一必殺技、第二進化=第二必殺技に更新)。
    @discardableResult
    static func evolve(_ data: inout SaveData, characterID: UUID) -> Bool {
        guard let index = data.characters.firstIndex(where: { $0.id == characterID }) else { return false }
        let chara = data.characters[index]
        guard chara.canEvolve else { return false }
        let element = chara.job().element
        guard data.stoneCount(element) > 0 else { return false }

        data.elementStones[element.rawValue, default: 1] -= 1
        data.characters[index].stage += 1
        data.characters[index].ultimate = JobCatalog.ultimate(
            for: chara.job(), stage: data.characters[index].stage)
        return true
    }
}
