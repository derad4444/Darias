//
//  DariasWidgetsBundle.swift
//  DariasWidgets
//
//  ウィジェット拡張のエントリーポイント
//

import SwiftUI
import WidgetKit

@main
struct DariasWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CalendarGridWidget()
        CalendarWidget()
        MemoWidget()
        TodoWidget()
    }
}
