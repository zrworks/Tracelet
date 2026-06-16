//
//  TraceletWidgetLiveActivity.swift
//  TraceletWidget
//
//  Created by Kiran on 16/06/26.
//

import ActivityKit
import WidgetKit
import SwiftUI
import tracelet_ios
import TraceletSDK

@available(iOS 16.2, *)
struct TraceletWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TraceletActivityAttributes.self) { context in
            // Lock screen/banner UI
            TraceletLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Tracking")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Live")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                }
            } compactLeading: {
                Image(systemName: "location.fill").foregroundColor(.blue)
            } compactTrailing: {
                Text("Live")
            } minimal: {
                Image(systemName: "location.fill").foregroundColor(.blue)
            }
        }
    }
}

