import Foundation

/// セーブデータの読み書き。App Group コンテナに JSON で保存する
enum GameStore {
    private static var saveURL: URL {
        let base = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(AppConstants.saveFileName)
    }

    static func load() -> SaveData {
        guard let data = try? Data(contentsOf: saveURL),
              let save = try? JSONDecoder().decode(SaveData.self, from: data)
        else {
            let fresh = SaveData.newGame()
            save(fresh)
            return fresh
        }
        return save
    }

    static func save(_ data: SaveData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: saveURL, options: .atomic)
    }
}
