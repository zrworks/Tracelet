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
            // Custom Lock screen/banner UI
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(context.state.status)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                Spacer()
                
                VStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .foregroundColor(.cyan)
                        .font(.headline)
                    Text("LIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                        .padding(.top, 2)
                }
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.05, green: 0.05, blue: 0.1))
            .activitySystemActionForegroundColor(Color.white)
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.cyan)
                        Text("Tracking")
                            .fontWeight(.bold)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("LIVE")
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            } compactLeading: {
                Image(systemName: "paperplane.fill").foregroundColor(.cyan)
            } compactTrailing: {
                Text("LIVE").foregroundColor(.red).fontWeight(.bold)
            } minimal: {
                Image(systemName: "paperplane.fill").foregroundColor(.cyan)
            }
        }
    }
}

