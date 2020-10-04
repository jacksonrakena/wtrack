//
//  WTrackApp.swift
//  WTrack
//
//  Created by Jackson Rakena on 4/Oct/20.
//

import SwiftUI

@main
struct WTrackApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
