# FlowStack

FlowStack is a SwiftUI navigation router for iOS 16+. It gives an app-level navigation layer for `NavigationStack`, push/pop flows, sheet presentation, full-screen cover presentation, root replacement, global dialogs, route identity, navigation guards, async transition queues, and default navigation styling.

Use FlowStack when you want navigation to be driven from a single router instead of scattering `NavigationLink`, `.sheet`, `.fullScreenCover`, and alert state across many views.

## Features

- SwiftUI `NavigationStack` router for iOS 16+.
- Type-safe route enum support with `Hashable` or `RouteHashable`.
- Push, multi-push, pop, pop-to-root, pop-to-route, and replace current screen.
- Push then remove the previous screen with `pushRemovingPrevious`.
- Replace root with refreshed root identity, even when setting the same route again.
- Present nested `sheet` and `fullScreenCover` stacks; each presentation owns its own navigation path.
- Dismiss active, specific, nested, or all presented stacks.
- Global dialog overlay above root, pushed screens, sheets, and full-screen covers.
- Queue, replace, ignore, or clear global dialogs.
- Default style system for every stack, modal, root screen, and pushed destination.
- Context-aware styling by stack index, stack id, presentation style, root route, screen route, and screen depth.
- Sync and async preconditions for navigation guards, login checks, permissions, paywall gates, and save-before-leave flows.
- Serialized async navigation queue to avoid overlapping SwiftUI transitions.
- Operation history for debugging applied and blocked navigation actions.

## Keywords

SwiftUI navigation, NavigationStack router, iOS navigation, Swift Package Manager, SPM, push pop navigation, sheet router, fullScreenCover router, global dialog, alert coordinator, route enum, deep link navigation, app router, navigation coordinator, SwiftUI coordinator, iOS 16.

## Route

For simple routes, use any `Hashable` type. For routes with closures, bindings, view models, or custom payloads, conform to `RouteHashable`:

```swift
enum AppRoute: RouteHashable {
    case splash
    case main
    case webView(String)
    case colorPicker(initialHex: String, didPick: (Color) -> Void)
}
```

`RouteHashable` auto-generates equality and hashing from a route id. Override `id` when the associated payload is complex and needs a stable production identity:

```swift
enum AppRoute: RouteHashable {
    case detail(User)

    var id: String {
        switch self {
        case .detail(let user):
            return "detail_\(user.id)"
        }
    }
}
```

## Root Host

```swift
@StateObject private var router = FlowRouter<AppRoute, AppDialog>(root: .splash)

var body: some View {
    FlowStackView(router: router) { route in
        screen(for: route)
    } destination: { route in
        screen(for: route)
    } dialog: { dialog in
        AnyView(AppDialogView(dialog: dialog))
    }
}
```

`FlowStackView` supports nested `sheet` and `fullScreenCover` presentations. Each presented stack owns its own `NavigationStack`.

The `dialog` builder is optional. When provided, it is rendered as a global overlay above the whole navigation tree, including pushed screens, sheets, and full-screen covers.

## Default Style

The default style mirrors the base app pattern: navigation bars are hidden and text alignment is leading.

```swift
FlowStackView(router: router) { route in
    screen(for: route)
} destination: { route in
    screen(for: route)
}
```

Customize the style once and it is applied to every root screen, pushed destination, sheet, and full-screen stack:

```swift
let style = FlowNavigationStyle.default
    .navigationBarHidden(true)
    .multilineTextAlignment(.leading)
    .screenStyle { view in
        view
            .background(Color.appBackground)
            .preferredColorScheme(.light)
    }
    .stackStyle { view in
        view
            .tint(.primary)
    }
    .modalStyle { view in
        view
            .presentationDragIndicator(.visible)
    }

FlowStackView(router: router, style: style) { route in
    screen(for: route)
} destination: { route in
    screen(for: route)
}
```

Use `screenStyle` for all screens, `stackStyle` for each `NavigationStack`, and `modalStyle` for every presented stack.

Each style hook also has a context-aware overload with the stack index:

```swift
let style = FlowNavigationStyle.default
    .screenStyle { view, context in
        view
            .background(context.isRootStack ? Color.white : Color.secondarySystemBackground)
    }
    .modalStyle { view, context in
        view
            .presentationDragIndicator(context.stackIndex > 0 ? .visible : .hidden)
    }
    .stackStyle { view, context in
        view
            .tint(context.presentationStyle == .fullScreenCover ? .red : .primary)
    }
```

`FlowNavigationStyle.Context` exposes `stackIndex`, `stackID`, `presentationStyle`, `isRootStack`, `rootRoute`, `screenRoute`, `screenDepth`, and `isRootScreen`.

It also exposes route information, which is the preferred way to style a screen. Checking the concrete SwiftUI view type after type erasure is not reliable.

```swift
let style = FlowNavigationStyle.default
    .screenStyle { view, context in
        if context.screenRoute(as: AppRoute.self) == .home {
            view.background(Color.homeBackground)
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
```

## Global Dialog

Global dialogs are app-wide overlays controlled by the router. Use them for alerts, confirmation dialogs, loading blockers, permission prompts, session-expired dialogs, and other UI that must sit above every stack.

Define your dialog model as `Identifiable`:

```swift
enum AppDialog: Identifiable, Equatable {
    case networkError
    case sessionExpired
    case deleteLogo(id: String)

    var id: String {
        switch self {
        case .networkError:
            return "networkError"
        case .sessionExpired:
            return "sessionExpired"
        case .deleteLogo(let id):
            return "deleteLogo_\(id)"
        }
    }
}
```

Render it once at the root host:

```swift
FlowStackView(router: router) { route in
    screen(for: route)
} destination: { route in
    screen(for: route)
} dialog: { dialog in
    AnyView(
        AppDialogView(dialog: dialog)
    )
}
```

The dialog view receives a `Binding<AppDialog?>`. Set it to `nil` when the user closes the current dialog:

```swift
struct AppDialogView: View {
    @Binding var dialog: AppDialog?

    var body: some View {
        switch dialog {
        case .networkError:
            ConfirmDialog(
                title: "Network Error",
                onClose: { dialog = nil }
            )

        case .sessionExpired:
            ConfirmDialog(
                title: "Session Expired",
                onClose: { dialog = nil }
            )

        case .deleteLogo:
            ConfirmDialog(
                title: "Delete Logo",
                onClose: { dialog = nil }
            )

        case nil:
            EmptyView()
        }
    }
}
```

Show a dialog from any place that can access the router:

```swift
router.showGlobalDialog(.networkError, policy: .queue)
router.showGlobalDialog(.sessionExpired, policy: .replace)
```

Policy behavior:

| Policy | Behavior | Use case |
| --- | --- | --- |
| `.replace` | Show immediately and clear queued dialogs. | Critical dialogs such as session expired, forced update, hard blocker. |
| `.replaceKeepingQueue` | Show immediately but keep queued dialogs for later. | Temporarily interrupt current dialog flow, then continue queued dialogs. |
| `.queue` | Show now if no dialog is visible, otherwise enqueue. | Non-critical alerts that should be shown one by one. |
| `.ignoreIfVisible` | Show only when no dialog is visible. | Toast-like or low-priority dialogs that should not interrupt current UI. |

Dismiss and queue control:

```swift
router.hideGlobalDialog()
router.clearGlobalDialogs()
router.queuedGlobalDialogCount
```

`hideGlobalDialog()` hides the current dialog. If the queue has another dialog, it becomes visible immediately. `clearGlobalDialogs()` removes both the visible dialog and all queued dialogs.

Example queue:

```swift
router.showGlobalDialog(.networkError, policy: .queue)
router.showGlobalDialog(.deleteLogo(id: "1"), policy: .queue)

router.hideGlobalDialog()
// .deleteLogo(id: "1") is now visible.
```

Example replace:

```swift
router.showGlobalDialog(.networkError, policy: .queue)
router.showGlobalDialog(.deleteLogo(id: "1"), policy: .queue)
router.showGlobalDialog(.sessionExpired, policy: .replace)

router.hideGlobalDialog()
// No old queued dialog appears because .replace clears the queue.
```

## Actions

```swift
router.setRoot(.main)
router.push(.detail(id))
router.pushRemovingPrevious(.main)
router.replaceCurrent(with: .settings)
router.pop()
router.popToRoot()
router.sheet(.colorPicker(initialHex: "#FFFFFF") { _ in })
router.fullScreenCover(.paywall)
router.dismiss()
router.dismissAll()
```

## Conditions

Each action can receive a one-off condition. The condition sees the operation and the previous stacks.

```swift
router.push(.settings) { operation, previousStacks in
    session.isLoggedIn
}
```

Default conditions can be registered per action kind:

```swift
router.setDefaultPrecondition(for: .push) { operation, previousStacks in
    session.isLoggedIn
}
```

The one-off condition takes priority over the default condition.

## Async Gates And Queue

Use async variants when navigation depends on permission, paywall, saving draft, login, or another asynchronous check:

```swift
await router.pushAsync(.editor) { operation, previousStacks in
    await permissions.requestPhotoAccess()
}
```

Async actions are serialized through the router queue. Set a small delay if SwiftUI modal transitions need spacing:

```swift
router.queuedTransitionDelayNanoseconds = 250_000_000
await router.sheetAsync(.picker)
await router.fullScreenCoverAsync(.paywall)
```

## Debugging

The router records applied and blocked operations:

```swift
router.operationHistory
router.clearOperationHistory()
router.maximumOperationHistoryCount = 100
```

Disable fallback route id warnings if needed:

```swift
FlowRouteIDDiagnostics.warnsOnFallbackID = false
```

## License

FlowStack is available under the MIT license. See [LICENSE](LICENSE) for details.
