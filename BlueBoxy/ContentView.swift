//
//  ContentView.swift
//  BlueBoxy
//
//  Created by MYLES on 10/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appEnvironment = AppEnvironment()
    @StateObject private var navigationCoordinator = NavigationCoordinator()
    
    var body: some View {
        RootView()
            .withAppEnvironment(appEnvironment)
            .environmentObject(navigationCoordinator)
            .environmentObject(appEnvironment.authViewModel)
            .environmentObject(appEnvironment.dashboardViewModel)
            .environmentObject(appEnvironment.messagesViewModel)
            .environmentObject(appEnvironment.calendarViewModel)
    }
}

#Preview {
    ContentView()
}
