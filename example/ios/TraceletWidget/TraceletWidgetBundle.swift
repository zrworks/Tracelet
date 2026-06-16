//
//  TraceletWidgetBundle.swift
//  TraceletWidget
//
//  Created by Kiran on 16/06/26.
//

import WidgetKit
import SwiftUI

@main
@available(iOS 18.0, *)
struct TraceletWidgetBundle: WidgetBundle {
    var body: some Widget {
        TraceletWidget()
        TraceletWidgetControl()
        TraceletWidgetLiveActivity()
    }
}
