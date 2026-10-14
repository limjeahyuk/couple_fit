import ActivityKit
import SwiftUI
import WidgetKit

private let lime = Color(red: 0.776, green: 0.953, blue: 0.420)  // #C6F36B
private let muted = Color(red: 0.604, green: 0.627, blue: 0.675)  // #9AA0AC
private let bg = Color(red: 0.067, green: 0.075, blue: 0.094)  // #111318

@main
struct WorkoutWidgetBundle: WidgetBundle {
  var body: some Widget { WorkoutActivityWidget() }
}

struct WorkoutActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: WorkoutAttributes.self) { ctx in
      LockScreen(ctx: ctx)
        .padding(16)
        .activityBackgroundTint(bg)
        .activitySystemActionForegroundColor(lime)
    } dynamicIsland: { ctx in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label(ctx.attributes.routine, systemImage: "dumbbell.fill").font(.caption.bold()).foregroundStyle(lime)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(ctx.attributes.startedAt, style: .timer).font(.caption.monospacedDigit()).multilineTextAlignment(.trailing)
        }
        DynamicIslandExpandedRegion(.bottom) { Main(ctx: ctx, big: 32) }
      } compactLeading: {
        Image(systemName: ctx.state.restEnd == nil ? "dumbbell.fill" : "timer").foregroundStyle(lime)
      } compactTrailing: {
        Clock(ctx: ctx).font(.caption.monospacedDigit()).frame(maxWidth: 48)
      } minimal: {
        Image(systemName: "timer").foregroundStyle(lime)
      }
      .keylineTint(lime)
    }
  }
}

/// Rest countdown while resting, otherwise total elapsed time. Both tick on their own.
private struct Clock: View {
  let ctx: ActivityViewContext<WorkoutAttributes>
  var body: some View {
    if let end = ctx.state.restEnd, end > .now {
      Text(timerInterval: Date.now...end, countsDown: true).foregroundStyle(lime)
    } else {
      Text(ctx.attributes.startedAt, style: .timer)
    }
  }
}

private struct Main: View {
  let ctx: ActivityViewContext<WorkoutAttributes>
  let big: CGFloat
  var body: some View {
    let s = ctx.state
    VStack(alignment: .leading, spacing: 6) {
      if let end = s.restEnd {
        HStack(alignment: .firstTextBaseline) {
          Text(ctx.isStale || end <= .now ? "휴식 끝! 다음 세트" : "휴식").font(.headline).foregroundStyle(lime)
          Spacer()
          if end > .now {
            Text(timerInterval: Date.now...end, countsDown: true)
              .font(.system(size: big, weight: .bold).monospacedDigit())
              .multilineTextAlignment(.trailing)
          }
        }
      } else {
        Text(s.title).font(.title3.bold()).lineLimit(1)
      }
      Text(s.detail).font(.footnote).foregroundStyle(muted).lineLimit(1)
      ProgressView(value: Double(s.doneSets), total: Double(max(s.totalSets, 1))).tint(lime)
    }
    .foregroundStyle(.white)
  }
}

private struct LockScreen: View {
  let ctx: ActivityViewContext<WorkoutAttributes>
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(ctx.attributes.routine, systemImage: "dumbbell.fill").font(.subheadline.bold()).foregroundStyle(lime)
        Spacer()
        Text(ctx.attributes.startedAt, style: .timer)
          .font(.subheadline.weight(.semibold).monospacedDigit())
          .multilineTextAlignment(.trailing)
          .foregroundStyle(.white)
      }
      Main(ctx: ctx, big: 40)
    }
  }
}
