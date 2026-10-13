# FlowStack

FlowStack owns SwiftUI navigation state for root/pushed screens, nested modal
flows, independent tab stacks, and global dialogs. Apps own business decisions,
route models, deep-link parsing, persistence, and screen rendering.

- iOS 16+ and macOS 13+, Swift 6; no third-party dependencies.
- MainActor-isolated commands and observation.
- Per-operation conditions, a final guard, FIFO async gates, and cancellation.
- Fresh screen identities for repeated routes and diagnostic operation history.
- Full-screen covers use a sheet fallback on macOS.

## Installation

In Xcode, use **File → Add Package Dependencies** with
`https://github.com/tu-konnichiwa/FlowStack.git`, select version `1.0.3`, and
add the FlowStack product to your app. To declare the same dependency in a
consumer package:

```swift
// In the consumer's Package.swift:
dependencies: [
    .package(url: "https://github.com/tu-konnichiwa/FlowStack.git", from: "1.0.3")
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "FlowStack", package: "FlowStack")
    ])
]
```

For local development, replace the versioned URL dependency with
`.package(path: "../FlowStack")`. See the iOS app example under `Examples/` for
a native consumer integration.

## Quick start — no dialogs required

This complete host uses only public APIs. Retain one router for the lifetime of
the flow; creating it repeatedly in `body` resets navigation.

```swift
import FlowStack
import SwiftUI

enum AppRoute: Hashable {
    case catalog
    case product(Int)
}

@MainActor
struct CatalogFlow: View {
    @StateObject private var router = FlowRouter<AppRoute, FlowNoDialog>(root: .catalog)

    var body: some View {
        FlowStackView(router: router, style: .default.navigationBarHidden(false)) { route in
            switch route {
            case .catalog:
                Button("Product 42") { router.push(.product(42)) }
                    .navigationTitle("Catalog")
            case .product(let id):
                Text("Product \(id)")
                    .navigationTitle("Product")
            }
        }
    }
}
```

The compatibility style default hides the iOS navigation bar. The example opts
into native back/title controls. Use any immutable `Hashable` route; prefer IDs
over large models or mutable reference payloads. Each push creates a distinct
screen even when route values are equal.

## Commands and targeting

Commands return `true` for accepted actions, including valid no-ops; `false`
means rejected. Inspect `operationHistory.last?.outcome` for diagnostics.

```swift
router.push(.product(42))
router.replaceCurrent(with: .product(84))
router.pushRemovingPrevious(.product(42))
router.pop()
router.popToRoot()
router.popTo(.product(42))             // Last matching pushed route; keeps it.
router.popTo(.product(42), match: .inclusive) // Removes the matching route too.
router.replacePath(root: .catalog, path: [.product(42)])
router.setRoot(.catalog, path: [.product(42)], refreshIfSameRoute: false)
```

`setRoot` dismisses all modals. `replacePath` changes only the selected stack.
When `refreshIfSameRoute` is false and the root is equal, `setRoot` preserves its
stack/root identity while replacing the path. The default true recreates it.
`pushRemovingPrevious` and `replaceCurrent` replace the top pushed screen, or
replace the stack root if its path is empty.

Targets are `.active` (default), `.root`, or `.stack(id)`. Capture the root stack
ID before presenting a modal if you need to navigate behind it:

```swift
let rootID = router.rootStack.id
router.sheet(.product(42))
router.push(.product(84), on: .stack(rootID))
router.dismiss()
```

A removed stack ID returns false with `.invalidTarget`; resolve a current ID
before retrying. `popTo` only searches the pushed path; missing routes produce
`.routeNotFound`. Bulk push evaluates each route, continues after rejection,
and returns aggregate success; it can partially apply. An empty list succeeds.

## Modal flows

```swift
router.sheet(.product(42), options: .init(allowsInteractiveDismiss: false))
router.fullScreenCover(.product(84))
router.dismiss()       // Top modal; dismissing the root is a successful no-op.
router.dismissAll()    // Keeps root path and global dialogs.
```

Every modal has an independent pushed path. Dismissing a specific modal also
clears modals above it by default; set
`clearsNestedPresentationOnDismiss: false` to keep/reparent them. `pop(count:)`
removes pushed screens and dismisses a modal if the count exceeds its path depth.
It never removes the root stack. `present(style: .root)` returns false with
`.invalidPresentationStyle`; use `setRoot` instead.

Presentation options control state policy. Put visual modifiers such as
`.presentationDetents([.medium, .large])` on the screen or in `modalStyle`.
Some SwiftUI modifiers require an OS newer than the package's minimum; apply
appropriate availability checks in your app.

## Conditions, async ordering, and cancellation

```swift
router.setDefaultPrecondition(for: .push) { operation, previousStacks in
    // Replace with an app-owned presentation decision.
    !previousStacks.isEmpty
}
router.push(.product(42)) { _, _ in true } // Overrides the sync default.

router.setDefaultAsyncPrecondition(for: .present) { _, previousStacks in
    !previousStacks.isEmpty
}
let accepted = await router.sheetAsync(.product(42))
```

Synchronous commands use an explicit condition or the synchronous default.
Async commands use an explicit async condition or the async default and bypass
the synchronous default. Both still run `guardOperation` as a final veto.

Async calls acquire a FIFO turn **before** evaluating their gate, so later gates
see earlier commits. Cancellation while waiting removes the request promptly;
cancellation during a gate prevents its commit once the gate returns. Gates
must honor cancellation themselves. Cancellation after commit does not undo it.
Sync commands remain immediate and can run while a gate awaits; an explicit
stack target is revalidated at commit. `.active` resolves at commit time.

Awaiting a queued command inside a gate/action on the same router returns false
with `.reentrantTransition`, including child tasks inheriting that gate's task
context. Perform follow-up navigation after the outer command returns. Avoid
recursive routing from synchronous conditions/guards.

`queued { ... }` serializes a custom synchronous action with async commands.
`queuedTransitionDelayNanoseconds` adds spacing after a successful queued action
(default zero); it does not track SwiftUI animation completion. Batch async
pushes hold a separate turn per route and allow interleaving.

## Global dialogs

Define an `Identifiable` model and supply a concrete view builder; no `AnyView`
is required. Legacy builders returning `AnyView` remain supported.

```swift
enum AppDialog: Identifiable {
    case signInRequired
    var id: String { "signInRequired" }
}

// In an app-owned SwiftUI host:
@StateObject private var router = FlowRouter<AppRoute, AppDialog>(root: .catalog)

var body: some View {
    FlowStackView(router: router) { route in
        Text(String(describing: route))
    } dialog: { binding in
        Color.clear.frame(width: 0, height: 0)
            .alert(item: binding) { _ in
                Alert(title: Text("Sign in required"))
            }
    }
}
```

The renderer is hosted on the active stack, including inside a sheet or cover.
Clearing its binding hides the visible dialog and promotes the next one. Give
repeated dialog instances distinct IDs when delayed dismissals must distinguish
them; stale callbacks with a different ID are ignored. Navigation resets do not
clear dialogs; call `clearGlobalDialogs()` explicitly.

| Policy | Effect |
| --- | --- |
| `.replace` (default) | Replace visible dialog and clear waiting dialogs |
| `.replaceKeepingQueue` | Replace visible dialog and retain waiting dialogs |
| `.queue` | Show when empty; otherwise append |
| `.interrupt` | Show new dialog; move current one to front of queue |
| `.ignoreIfVisible` | Drop request while a dialog is visible |

`showGlobalDialog(_:policy:)`, `hideGlobalDialog()`, and `clearGlobalDialogs()`
manage the queue. `Binding.flowDialogFilter { ... }` lets separate system/custom
renderers handle matching cases without clearing another renderer's dialog.

## Tabs

```swift
enum AppTab: Hashable { case shop, favorites }
let tabs = FlowTabRouter<AppTab, AppRoute, FlowNoDialog>(tabs: [
    FlowTab(.shop, root: .catalog),
    FlowTab(.favorites, root: .catalog)
])
tabs.push(.product(42), on: .favorites) // Does not switch selection.
tabs.selectTab(.favorites)

FlowTabStackView(router: tabs, style: .default.navigationBarHidden(false)) { route in
    Text(String(describing: route))
} label: { tab in
    Text(String(describing: tab))
}
```

Retain the tab router with `StateObject` in an actual host. Tab configuration
must be nonempty with unique IDs; selection and direct lookup require a
configured ID. For parsed/external input, use `selectTabIfPresent(_:)` and
`routerIfPresent(for:)` to get false/nil safely. Initial `tabs` are configuration,
not current navigation snapshots.

Use `router(for:)` for per-tab async commands, guards, and history. Render
app-wide dialogs through `FlowTabStackView` and call dialog methods on the tab
router; child-router dialogs are not rendered by that host.

## Styling and observability

```swift
let style = FlowNavigationStyle.default
    .navigationBarHidden(false)
    .screenStyle { view, context in
        view.padding(context.isRootScreen ? 16 : 8)
    }
```

Transforms receive stack index/ID, presentation kind, root/screen route, and
screen depth. Typed accessors `context.rootRoute(as: AppRoute.self)` and
`screenRoute(as:)` return optional route values. Repeated `screenStyle`,
`stackStyle`, or `modalStyle` calls replace the previous transform.

`operationHistory` retains before/after snapshots for commands. The default
limit is 200; lowering a positive limit trims immediately. Zero/negative means
unlimited. Clear it when retained payloads are no longer needed.
`didApplyOperation` is called after success but receives **previous** stacks;
read the router for current state. Stored callbacks should capture their owner
weakly if that owner also retains the router.

## Native gestures, restoration, and limitations

- Native SwiftUI path/presentation binding writes bypass conditions, guards, and
  history. For unsaved edits, disable interactive modal dismissal and provide
  explicit guarded close/back controls. Hide/replace the native back control
  when confirmation is required.
- `bindingForPath(stackID:)` preserves equal prefix screen identities; removed
  stacks read empty and ignore writes. A presented-stack binding captures its
  dismissal target; recreate it as presentation changes.
- The app owns URL validation and Codable serialization. Routes with closures,
  bindings, or services need app-owned reconstruction. FlowStack does not encode
  UUID screen identities for restoration.
- `RouteHashable` supports explicit stable String IDs for non-Hashable payloads.
  Its reflection fallback is for prototypes, can collide, and must not be used
  as a persistence format. Prefer an explicit `id` in production.
- No timeout/retry/authentication policy is provided. Inject app services into
  your presentation coordinator, not into route IDs or the navigation reducer.
- SwiftUI visual layering, animation completion, and device gestures require
  app-level UI tests. Package tests verify state and compile view builders.

See [ShopDemo](Examples/ShopDemo/README.md) for tested deep links, checkout gating,
modal navigation, and restoration. See [API contracts](Documentation/API.md),
[architecture decisions](Documentation/Architecture.md), and
[consumer review and release gaps](Documentation/ConsumerReview.md).

## Testing and compatibility

```sh
swift test
open Examples/ShopDemo/ShopDemo.xcodeproj
./Scripts/validate.sh # Tests, release build, and Xcode iOS app build; requires Xcode.
```

Use `DEVELOPER_DIR` to select a compatible Xcode toolchain when command-line tools
point to another SDK. The validation script uses temporary build/cache paths and removes them on exit.
It runs iOS simulator tests when a simulator runtime is available and always
builds the generic iOS simulator destination. The GitHub Actions workflow runs
the same checks on macOS.

Release policy: follow semantic versioning, document behavior corrections, and
provide migration notes before tagging. This refactor preserves command
signatures and style defaults. New `FlowOperationOutcome` cases require updating
exhaustive consumer switches; observers now receive the promised previous state,
missing targets fail, cancellation is respected, and root refresh opt-out works.
Consumers relying on the former incorrect behavior must migrate. No new release
has been published by this change.

## License

MIT — see [LICENSE](LICENSE).
