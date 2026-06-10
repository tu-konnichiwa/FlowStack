# FlowStack

FlowStack is a SwiftUI navigation router for iOS 16+ and macOS 13+ that centralizes navigation in one place. It helps you replace scattered NavigationLink, sheet, fullScreenCover, and alert state with a single router and a predictable API.

If you want a navigation layer that supports:

- push / pop / replace / reset flows
- nested sheets and full-screen covers
- app-wide dialogs
- async guards and serialized transitions
- route-aware styling and debugging

then FlowStack is designed for that.

## Why FlowStack

FlowStack is a good fit when your app needs one source of truth for navigation state. It is especially useful for:

- feature-rich apps with multiple nested flows
- onboarding and auth flows that need guards
- deep-link / state restoration workflows
- apps that want to avoid manual navigation state spread across views
- teams that want consistent styling and debug visibility for navigation events

## What you get

- NavigationStack-based routing for root and pushed screens
- Nested sheet and full-screen cover stacks
- Global dialog overlay above every stack
- Sync and async navigation guards
- Serialized async transitions to avoid race conditions
- Route-aware styling hooks
- Operation history for applied and blocked actions
- Route identity helpers for stable navigation state

## Requirements

- iOS 16+
- macOS 13+
- Swift 6

On macOS, FlowStack uses a sheet fallback for full-screen presentation behavior.

## Installation

### Swift Package Manager

Add FlowStack as a dependency in your app target.

#### Xcode

1. Open File > Add Package Dependencies...
2. Add the repository URL:
   https://github.com/tu-konnichiwa/FlowStack.git
3. Choose a version rule such as Up to Next Major Version.
4. Add the FlowStack product to your app target.

#### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/tu-konnichiwa/FlowStack.git", from: "1.0.2")
],

.targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "FlowStack", package: "FlowStack")
        ]
    )
]
```

Then import it:

```swift
import FlowStack
```

## Quick start

### 1. Define routes

Use any Hashable route for simple cases.

```swift
enum AppRoute: Hashable {
    case splash
    case home
    case detail(Int)
    case settings
}
```

For routes that carry closures, bindings, or complex payloads, conform to RouteHashable and provide a stable id.

```swift
enum AppRoute: RouteHashable {
    case detail(User)
    case colorPicker(initialHex: String, didPick: (Color) -> Void)

    var id: String {
        switch self {
        case .detail(let user):
            return "detail_\(user.id)"
        case .colorPicker(let initialHex, _):
            return "colorPicker_\(initialHex)"
        }
    }
}
```

### 2. Create the router and host the view

```swift
@StateObject private var router = FlowRouter<AppRoute, AppDialog>(root: .splash)

var body: some View {
    FlowStackView(router: router) { route in
        screen(for: route)
    } dialog: { dialog in
        AppDialogView(dialog: dialog)
    }
}
```

Use the screen builder to render the view for any given route in the navigation stack.

### 3. Build screens

```swift
@ViewBuilder
func screen(for route: AppRoute) -> some View {
    switch route {
    case .splash:
        SplashView()
    case .home:
        HomeView()
    case .detail:
        DetailView()
    case .settings:
        SettingsView()
    }
}
```

## Core navigation API

### Root and stack operations

```swift
router.setRoot(.home)
router.push(.detail(42))
router.pushRemovingPrevious(.settings)
router.replaceCurrent(with: .settings)
router.replacePath(root: .home, path: [.detail(42), .settings])
router.pop()
router.popToRoot()
router.popTo(.detail(42))
```

### Present modal stacks

```swift
router.sheet(.picker)
router.fullScreenCover(.paywall)
router.dismiss()
router.dismissAll()
```

### Target a specific stack

You can push into the root stack, the active modal stack, or a specific stack by id.

```swift
let rootID = router.rootStack.id
router.sheet(.picker)
router.push(.settings, on: .stack(rootID))
```

### Presentation options

Use FlowPresentationOptions when you need to control modal behavior.

```swift
let options = FlowPresentationOptions(
    allowsInteractiveDismiss: false,
    clearsNestedPresentationOnDismiss: true
)

router.sheet(.picker, options: options)
```

FlowPresentationOptions intentionally stores only navigation-state behavior. SwiftUI presentation modifiers such as detents, backgrounds, drag indicators, compact adaptation, and corner radius should stay on the presented screen or in `FlowNavigationStyle.modalStyle`, because SwiftUI applies them at view boundaries.

```swift
case .picker:
    PickerScreen()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.thinMaterial)
```

Use `modalStyle` when the treatment depends on the presentation stack rather than a single screen.

```swift
let style = FlowNavigationStyle.default
    .modalStyle { view, context in
        if context.presentationStyle == .sheet {
            view.presentationCornerRadius(24)
        } else {
            view
        }
    }
```

## Conditions and guards

FlowStack supports both sync and async preconditions.

### Sync condition

```swift
router.push(.settings) { operation, previousStacks in
    session.isLoggedIn
}
```

### Default conditions

```swift
router.setDefaultPrecondition(for: .push) { operation, previousStacks in
    session.isLoggedIn
}
```

### Async gates

Use async gates for permissions, paywall checks, or save-before-leave flows.

```swift
await router.pushAsync(.editor) { operation, previousStacks in
    await permissions.requestPhotoAccess()
}

router.queuedTransitionDelayNanoseconds = 250_000_000
await router.sheetAsync(.picker)
await router.fullScreenCoverAsync(.paywall)
```

The one-off condition overrides the default condition.

## Global dialogs

Global dialogs are rendered above the full navigation tree, including pushed screens, sheets, and full-screen covers.

### Define your dialog model

```swift
enum AppDialog: Identifiable, Equatable {
    case networkError
    case sessionExpired
    case deleteLogo(id: String)
    case customToast(String)

    var id: String {
        switch self {
        case .networkError:
            return "networkError"
        case .sessionExpired:
            return "sessionExpired"
        case .deleteLogo(let id):
            return "deleteLogo_\(id)"
        case .customToast(let message):
            return "customToast_\(message)"
        }
    }

    var title: String {
        switch self {
        case .networkError:
            return "Network error"
        case .sessionExpired:
            return "Session expired"
        case .deleteLogo:
            return "Delete logo?"
        case .customToast:
            return "Saved"
        }
    }

    var message: String {
        switch self {
        case .networkError:
            return "Check your connection and try again."
        case .sessionExpired:
            return "Please sign in again."
        case .deleteLogo:
            return "This action cannot be undone."
        case .customToast(let message):
            return message
        }
    }

    var isSystemAlert: Bool {
        if case .customToast = self { return false }
        return true
    }

    var isCustomToast: Bool {
        if case .customToast = self { return true }
        return false
    }
}
```

### Render native and custom dialogs

```swift
FlowStackView(router: router) { route in
    screen(for: route)
} dialog: { dialog in
    AnyView(
        ZStack {
            Color.clear
                .frame(width: 0, height: 0)
                .alert(item: dialog.flowDialogFilter(\.isSystemAlert)) { dialog in
                    Alert(
                        title: Text(dialog.title),
                        message: Text(dialog.message)
                    )
                }

            CustomToastView(dialog: dialog.flowDialogFilter(\.isCustomToast))
        }
    )
}
```

`flowDialogFilter` lets multiple renderers share the same FlowStack dialog binding safely. A native alert renderer can ignore custom overlay cases, and a custom renderer can ignore system alert cases without clearing each other.

### Show and hide dialogs

```swift
router.showGlobalDialog(.networkError, policy: .queue)
router.showGlobalDialog(.sessionExpired, policy: .replace)
router.showGlobalDialog(.networkError, policy: .interrupt)
router.hideGlobalDialog()
router.clearGlobalDialogs()
```

### Dialog policies

| Policy | Behavior | Recommended use |
| --- | --- | --- |
| replace | Replaces the visible dialog and clears the queue | critical blockers |
| replaceKeepingQueue | Replaces the visible dialog but keeps queued dialogs | urgent replacement that should not lose queued work |
| queue | Shows immediately if possible, otherwise appends to the queue | normal alerts |
| interrupt | Shows immediately and moves the visible dialog to the front of the queue | B should show before A, then return to A |
| ignoreIfVisible | Ignores the request while a dialog is visible | low-priority toasts |

For example, `A` visible then `B` with `.queue` gives `A -> B`. `A` visible then `B` with `.interrupt` gives `B -> A`. `A` visible, `B` queued, then `C` with `.replaceKeepingQueue` gives `C -> B`.

## Styling

FlowStack provides one style object for every stack, screen, and modal layer.

### Default style

```swift
FlowStackView(router: router) { route in
    screen(for: route)
}
```

### Customize style globally

```swift
let style = FlowNavigationStyle.default
    .navigationBarHidden(true)
    .multilineTextAlignment(.leading)
    .screenStyle { view in
        view
            .background(Color(.systemBackground))
            .ignoresSafeArea()
    }
    .stackStyle { view in
        view.tint(.accentColor)
    }
    .modalStyle { view in
        view
            .presentationDragIndicator(.visible)
    }

FlowStackView(router: router, style: style) { route in
    screen(for: route)
}
```

### Context-aware styling

Use the style context to apply different treatment per stack, root route, screen route, or depth.

```swift
let style = FlowNavigationStyle.default
    .screenStyle { view, context in
        if context.screenRoute(as: AppRoute.self) == .home {
            view.background(Color.white)
        } else {
            view
        }
    }
    .stackStyle { view, context in
        if context.rootRoute(as: AppRoute.self) == .editor {
            view.tint(.orange)
        } else {
            view
        }
    }
    .modalStyle { view, context in
        if context.presentationStyle == .fullScreenCover {
            view.presentationCornerRadius(24)
        } else {
            view
        }
    }
```

The context exposes:

- stackIndex
- stackID
- presentationStyle
- isRootStack
- rootRoute
- screenRoute
- screenDepth
- isRootScreen

Use context.route accessors instead of inspecting the concrete SwiftUI view type.

## Debugging and observability

FlowStack records applied and blocked operations.

```swift
router.operationHistory
router.clearOperationHistory()
router.maximumOperationHistoryCount = 100
router.didApplyOperation = { operation, previousStacks in
    print(operation)
}
```

If you want to inspect a route identity fallback warning, you can disable it.

```swift
FlowRouteIDDiagnostics.warnsOnFallbackID = false
```

## Common patterns

### Deep-link or restore navigation state

```swift
router.replacePath(root: .home, path: [.detail(42), .settings])
```

### Replace the current screen while keeping the stack

```swift
router.replaceCurrent(with: .settings)
```

### Push and remove the previous screen

```swift
router.pushRemovingPrevious(.main)
```

### Keep the same root route but refresh its identity

```swift
router.setRoot(.home)
```

## Recommendations for a top-tier README

To make the README feel polished and library-grade, keep the structure simple:

1. one-sentence value proposition
2. clear installation steps
3. a minimal working example
4. a feature table for key capabilities
5. answers for guard, async, dialog, styling, and debugging
6. a short section on best practices and limitations

## License

FlowStack is available under the MIT license. See LICENSE for details.
