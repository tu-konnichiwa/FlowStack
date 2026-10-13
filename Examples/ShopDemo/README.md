# ShopDemo — iOS app using FlowStack

Open `ShopDemo.xcodeproj` in Xcode and run the shared `ShopDemo` scheme on an
iOS 16+ simulator or device. This is a native iOS app with its own Xcode test target.

The Xcode project adds FlowStack through a **local Swift Package dependency**
to this repository's root. It builds the current checkout directly. For an app
outside this checkout, choose the Git URL and a released version in Xcode's
package settings.

The app walks through catalog → product → gated checkout sheet → nested address
screen. Its Info.plist registers the `flowshop` URL scheme, and
`flowshop://product/42` demonstrates app-owned deep-link parsing.
`snapshot()`/`restore(_:)` demonstrate app-owned Codable navigation restoration.
The app owns session services and persistence I/O; checkout authorization is
injected, and the demo does not call a real service.

Run the `ShopDemoTests` target from Xcode's Test navigator. It exercises
approved/denied checkout, nested navigation, deep-link validation, malformed
snapshots, and restoration. `../../Scripts/validate.sh` also builds and tests the
Xcode app target when an iOS Simulator runtime is available.
