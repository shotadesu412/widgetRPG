import Foundation

/// 朝昼夜の概念。ウィジェットと画面の背景演出に使う
enum TimeOfDay: CaseIterable {
    case morning, day, night

    static func current(_ date: Date = Date()) -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<10: return .morning
        case 10..<18: return .day
        default: return .night
        }
    }

    var label: String {
        switch self {
        case .morning: "朝"
        case .day: "昼"
        case .night: "夜"
        }
    }

    var symbolName: String {
        switch self {
        case .morning: "sunrise.fill"
        case .day: "sun.max.fill"
        case .night: "moon.stars.fill"
        }
    }
}

/// 天候。TODO: WeatherKit で実際の天気をウィジェットに反映する
enum Weather: String, CaseIterable {
    case clear, cloudy, rain, snow

    /// 実装までは時間帯ベースの擬似天候を返す
    static func current(_ date: Date = Date()) -> Weather {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        let hour = Calendar.current.component(.hour, from: date)
        return Weather.allCases[(day + hour / 6) % Weather.allCases.count]
    }

    var label: String {
        switch self {
        case .clear: "晴れ"
        case .cloudy: "曇り"
        case .rain: "雨"
        case .snow: "雪"
        }
    }

    var symbolName: String {
        switch self {
        case .clear: "sun.max"
        case .cloudy: "cloud"
        case .rain: "cloud.rain"
        case .snow: "cloud.snow"
        }
    }
}
