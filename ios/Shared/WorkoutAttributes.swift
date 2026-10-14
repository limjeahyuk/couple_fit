import ActivityKit
import Foundation

/// Shared by Runner (starts/updates the activity) and WorkoutWidget (draws it).
struct WorkoutAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var title: String  // current exercise
    var detail: String  // "세트 2 / 4 · 10회 · 40kg" or, while resting, "다음: 벤치프레스 3세트"
    var restEnd: Date?  // set while resting
    var doneSets: Int
    var totalSets: Int
  }

  var routine: String
  var startedAt: Date
}
