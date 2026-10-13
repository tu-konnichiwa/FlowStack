//
//  ExampleApp.swift
//  Example
//
//  Created by Tu Konnichiwa on 13/10/26.
//

import SwiftUI

@MainActor
@main
struct ExampleApp: App {
    @StateObject private var navigator = ShopNavigator()

    var body: some Scene {
        WindowGroup {
            ContentView(navigator: navigator)
        }
    }
}
