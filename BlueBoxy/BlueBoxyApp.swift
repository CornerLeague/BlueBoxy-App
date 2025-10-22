//
//  BlueBoxyApp.swift
//  BlueBoxy
//
//  Created by MYLES on 10/2/25.
//

import SwiftUI

@main
struct BlueBoxyApp: App {
    
    // Initialize RecentMessagesManager on app launch
    @StateObject private var recentMessagesManager = RecentMessagesManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recentMessagesManager)
        }
    }
}
