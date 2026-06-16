//
//  TraceletWidgetBundle.swift
//  TraceletWidget
//
//  Created by Kiran on 16/06/26.
//

import WidgetKit
import SwiftUI

@main
@available(iOS 16.2, *)
struct TraceletWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity must register on every supported OS (iOS 16.2+),
        // otherwise the system reports "Activity had no descriptor".
        TraceletWidgetLiveActivity()

        // The home-screen AppIntent widget and the Control widget require iOS 18.
        if #available(iOS 18.0, *) {
            TraceletWidget()
            TraceletWidgetControl()
        }
    }
}
