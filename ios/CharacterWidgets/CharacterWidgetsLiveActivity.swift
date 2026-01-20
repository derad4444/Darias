//
//  CharacterWidgetsLiveActivity.swift
//  CharacterWidgets
//
//  Created by 小野寺良祐 on 2025/11/16.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CharacterWidgetsAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CharacterWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CharacterWidgetsAttributes.self) { context in
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

extension CharacterWidgetsAttributes {
    fileprivate static var preview: CharacterWidgetsAttributes {
        CharacterWidgetsAttributes(name: "World")
    }
}

extension CharacterWidgetsAttributes.ContentState {
    fileprivate static var smiley: CharacterWidgetsAttributes.ContentState {
        CharacterWidgetsAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CharacterWidgetsAttributes.ContentState {
         CharacterWidgetsAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CharacterWidgetsAttributes.preview) {
   CharacterWidgetsLiveActivity()
} contentStates: {
    CharacterWidgetsAttributes.ContentState.smiley
    CharacterWidgetsAttributes.ContentState.starEyes
}
