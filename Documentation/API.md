# Public API contracts

## Ownership and concurrency

`FlowRouter<Route, Dialog>` is a MainActor ObservableObject. Retain it in the
presentation/composition layer with StateObject or an injected coordinator.
`FlowRouting` exposes read-only stacks, global dialog, and host identity for
observation. It is not a domain port: Combine observation belongs to presentation.

`Route` must be Hashable with stable equality/hash while stored. App-owned IDs
are usually sufficient. `RouteHashable` uses a String ID to exclude non-Hashable
payloads such as callbacks; override `id` in production. The reflection fallback
is not collision-proof or a serialization contract. `AnyRouteHashable` is a base
class with an explicit immutable ID. `FlowRouteIDDiagnostics.warnsOnFallbackID`
is a thread-safe logging toggle, default true; changing it does not change IDs.

`Dialog` is unconstrained for router state but must be Identifiable for SwiftUI
hosts and tab routers. `FlowNoDialog` is uninhabited and supports navigation-only
hosts. Give dialog instances distinct IDs if a stale dismissal must distinguish
two presentations of the same semantic message.

All router commands, gates, observers, binding access, and configuration occur
on MainActor. Stored callbacks retain captures. Use weak captures for owners
that also retain routers. Navigation history retains route payloads (including
closure captures) until trimmed/cleared. No background I/O runs inside FlowStack.

## State and targeting

`stacks` always has a root at index 0; subsequent elements are modal stacks.
`rootStack`, `activeStack`, `activeIndex`, `topRoute`, and `isPresenting` derive
from that state. Stack snapshots expose identity, root identity, root, pushed
path, style, and presentation options. Snapshot setters are not public.
`FlowRouteNode` equality/hash use its UUID only; payload equality does not merge
screen instances. `FlowStackState` equality includes its stored state/identities.

`FlowStackTarget.root` selects index 0. `.active` resolves when the command
commits; after an async suspension this can differ from the gate's snapshot.
`.stack(UUID)` selects that identity or rejects with invalidTarget.
`containsStack(id:)` checks whether an identity is still present.

`FlowPresentationOptions` defaults to interactive dismissal enabled and nested
presentations cleared when a modal is dismissed. These options contain state
policy only; visual modifiers belong to host/screen styling.

## Command matrix

All commands use the selected synchronous precondition and final guard, except
explicit early no-ops: nonpositive synchronous pop counts and empty bulk inputs.
Successful commands call the observer and record applied, including other valid
no-ops. A rejected command returns false without applying its mutation.

| Command | Effect / edge behavior |
| --- | --- |
| `init(root:)`, `init(root:path:)` | One root, no dialog or modal; initial pushed nodes have unique IDs |
| `setRoot(_:path:refreshIfSameRoute:condition:)` | Replaces all stacks; retains global dialogs. False refresh with equal root preserves stack/root identity; new path nodes still get new IDs |
| `push(_:on:condition:)` | Appends one new node; equal route payloads are allowed |
| `push(contentsOf:on:condition:)` | Individual pushes in order; continues after rejection, returns aggregate success; not atomic |
| `pushRemovingPrevious(_:on:condition:)` | Replaces previous top node, or root for an empty path |
| `replaceCurrent(with:on:condition:)` | Replaces top node, or root for an empty path; refreshes screen identity |
| `replacePath(root:path:on:condition:)` | Replaces one stack's root/path and root screen identity; keeps other stacks |
| `pop(count:on:condition:)` | Removes bounded path count; excess dismisses a modal. Never removes root stack |
| `popToRoot(on:condition:)` | Clears selected path; does not dismiss selected modal |
| `popTo(_:match:on:condition:)` | Last equal pushed route only. Exclusive keeps it; inclusive removes it; absent route rejects |
| `present(_:style:path:options:condition:)` | Appends modal; root style rejects with invalidPresentationStyle |
| `sheet`, `fullScreenCover` | Presentation conveniences; cover uses sheet on macOS |
| `dismiss(_:condition:)` | Dismiss selected modal; root is a valid no-op. Nested removal follows selected modal's options |
| `dismissAll(condition:)` | Keeps root including pushed path; dialogs remain |

Precondition and guard callbacks must not recursively issue synchronous commands.
Callbacks may inspect snapshots; they should return decisions without mutating
navigation. Observer callbacks run after commit and receive previous stacks.

## Async variants and queue lifecycle

Every command family has an Async variant with an `AsyncPrecondition`. The
navigation effect matches the synchronous command. A one-off async gate
replaces its async default; it does not combine with the synchronous default.
The final synchronous `guardOperation` still applies. This preserves the original
guard selection behavior and is covered by a regression test.

The FIFO turn covers gate evaluation, commit, and optional successful-command
spacing. The next gate receives the latest state after earlier async commits.
Synchronous commands are immediate and may mutate state while an async gate is
suspended; the command re-resolves its target before mutating.

Cancellation while waiting removes/resumes the waiter without waiting for the
active gate. Cancellation during a gate is checked when the gate returns, before
commit. A gate that ignores cancellation can occupy the queue until it returns;
FlowStack does not forcibly terminate app tasks or apply a timeout. After commit,
cancellation interrupts optional spacing and returns the committed result; it
never rolls back navigation. Set `queuedTransitionDelayNanoseconds` (UInt64,
default zero) for spacing, not animation completion.

A queued action/gate must not await another queued command on its own router.
The task-local ownership check returns false with reentrantTransition, including
child tasks inheriting the active gate context. A different router is allowed.
Perform same-router follow-ups after the outer call returns. A general
`queued { ... }` wrapper returns false for cancellation/reentrancy but does not
create its own history entry; any router commands it executes record normally.

Bulk `pushAsync(contentsOf:)` holds one turn per route, permits interleaving,
continues after failures, and can partially apply. Empty arrays succeed without
history even in a cancelled task. For atomic deep-link path replacement, use
`replacePath` or `setRoot` with an entire path instead of bulk pushes.

## Conditions, outcomes, and diagnostics

- `setDefaultPrecondition(for:_:)` / `setDefaultAsyncPrecondition(for:_:)` install
  or remove conditions keyed by FlowOperationKind.
- A per-call condition overrides its corresponding default.
- `clearDefaultPreconditions()` clears both maps but leaves guardOperation.
- `guardOperation` is the final synchronous veto for sync and async commands.
- `didApplyOperation` receives operation and **previous** stacks after success;
  current state is available from the router.

`FlowOperation` describes a command. setRoot/present do not encode every path,
option, or refresh flag; use record snapshots for the complete applied state.
`FlowOperationKind` groups defaults. `FlowOperationRecord` has ID, wall-clock
date, operation, previous/new stacks, and outcome.

| Outcome | Consumer action |
| --- | --- |
| applied | Continue; valid no-ops also succeed |
| blockedByPrecondition | Resolve the app-specific gate/condition and retry if appropriate |
| blockedByGuard | Resolve the final app policy veto |
| invalidTarget | Resolve a live stack ID; do not reuse a dismissed stack |
| routeNotFound | Choose a route present in the pushed path, or replacePath |
| invalidPresentationStyle | Use setRoot instead of present with root style |
| cancelled | Treat as cancellation; do not show an authentication/error dialog solely for it |
| reentrantTransition | Move same-router async follow-up outside the active gate/action |

The default history bound is 200. Positive changes trim immediately; zero or
negative means unlimited for compatibility. `clearOperationHistory()` releases
records. History is diagnostic, not persistent/auditable event storage; native
binding writes do not produce entries.

## Dialog scheduling

Single and tab routers share the same internal scheduling state machine:
replace clears queue; replaceKeepingQueue preserves queue; queue appends;
interrupt pushes visible to the front; ignoreIfVisible drops new while visible.
The default showGlobalDialog policy is replace. hideGlobalDialog promotes the
next queued dialog; clearGlobalDialogs removes visible and queue.
hideGlobalDialog(id:) ignores a different visible ID; nil hides unconditionally.
queuedGlobalDialogCount excludes the visible dialog.

Dialog binding nil writes promote the queue. Hosts capture the visible ID to
ignore late dismissals of a different dialog and ignore nil writes from bindings
created without a visible dialog. `flowDialogFilter` exposes matching cases and
only clears a currently matching case, allowing multiple native/custom renderers.

`FlowStackView` hosts the renderer on the active stack including modal layers.
`FlowTabStackView` hosts tab-router dialogs through the selected child stack;
its children do not render their own dialog state. Choose one app-wide owner.

## Tabs and bindings

FlowTab is initial configuration: ID, root, and initial path. FlowTabRouter
requires a nonempty set of unique IDs and an initial configured selection.
Invalid configuration produces an actionable precondition message. `selectedTab`
assignment, `selectTab`, and `router(for:)` require configured IDs. For untrusted
input, use `selectTabIfPresent` (false) and `routerIfPresent` (nil).

Forwarding commands take optional `on: Tab` (selected by default) without
switching selection. Push/pop/replace target a stack within that tab. Child
routers provide async commands, guards, history, and advanced bindings; the tab
router observes child changes. Retain both parent and child references as needed.

`bindingForSelectedTab()` validates IDs. `bindingForPath(stackID:)` writes route
values preserving equal prefix node identities. Removed stacks read empty and
ignore writes. Internal navigation-path bindings preserve node identities for
native NavigationStack gestures. `bindingForPresentedStack(style:)` reads the
latest matching presentation but nil writes dismiss only the ID captured when
created; non-nil writes do nothing. Recreate it when state changes.

Path/presentation binding writes bypass commands, guards, history, and observers.
This reflects native gestures already performed by SwiftUI. Disable gestures and
use explicit commands for guarded exits. State policy alone cannot guarantee a
platform gesture is blocked after it has occurred.

## Styling and SwiftUI hosts

FlowNavigationStyle is a value with stack/screen/modal transforms (AnyView plus
Context). Defaults: hidesNavigationBar=true on iOS, multilineTextAlignment=leading,
identity transforms. Fluent methods return copies; style methods replace their
transform rather than composing with earlier style methods. Use a single closure
when multiple modifiers should combine.

Context contains stackIndex/stackID/presentationStyle/isRootStack, rootRoute,
screenRoute, screenDepth/isRootScreen. Root screen depth is zero. Routes are
AnyHashable; typed accessors return nil for an incompatible type.

Both hosts retain screen/label/dialog builder closures and observe the supplied
router; they do not own its creation. Generic dialog builders accept concrete
SwiftUI views, while the original optional AnyView closures remain available.
Use ViewBuilder screen switches and apply OS availability checks for modifiers
newer than iOS 16/macOS 13. All UI construction and body evaluation occurs on
MainActor through SwiftUI's View contract.
