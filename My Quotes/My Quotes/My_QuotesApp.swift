//
//  My_QuotesApp.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/28/24.
//

import SwiftUI

@main
struct My_QuotesApp: App {
    @State private var store: LocalStore = .init()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    await store.initializeSyncEngine()
                }
        }
    }
}
