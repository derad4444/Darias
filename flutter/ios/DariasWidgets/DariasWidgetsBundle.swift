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
        TodoWidget()
        MemoWidget()
        CalendarWidget()
    }
}
