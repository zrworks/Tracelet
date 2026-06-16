//
//  TraceletWidgetLiveActivity.swift
//  TraceletWidget
//
//  Created by Kiran on 16/06/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TraceletWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct TraceletWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TraceletWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension TraceletWidgetAttributes {
    fileprivate static var preview: TraceletWidgetAttributes {
        TraceletWidgetAttributes(name: "World")
    }
}

extension TraceletWidgetAttributes.ContentState {
    fileprivate static var smiley: TraceletWidgetAttributes.ContentState {
        TraceletWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: TraceletWidgetAttributes.ContentState {
         TraceletWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: TraceletWidgetAttributes.preview) {
   TraceletWidgetLiveActivity()
} contentStates: {
    TraceletWidgetAttributes.ContentState.smiley
    TraceletWidgetAttributes.ContentState.starEyes
}
