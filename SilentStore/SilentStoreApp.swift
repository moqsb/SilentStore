//
//  SilentStoreApp.swift
//  SilentStore
//
//  Created by Mohammed Alqassab on 08-02-2026.
//

import SwiftUI
import CoreData

@main
struct SilentStoreApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
