//
//  shabbat_helperApp.swift
//  shabbat-helper
//
//  Created by Aharon Zilberman on 05/06/2026.
//

import SwiftUI

@main
struct shabbat_helperApp: App {
    init() {
        TimeFormatPreference.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
