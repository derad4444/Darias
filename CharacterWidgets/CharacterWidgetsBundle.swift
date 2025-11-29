//
//  CharacterWidgetsBundle.swift
//  CharacterWidgets
//
//  Created by 小野寺良祐 on 2025/11/16.
//

import WidgetKit
import SwiftUI

@main
struct CharacterWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CalendarWidget()
        MemoWidget()
        TodoWidget()
    }
}
