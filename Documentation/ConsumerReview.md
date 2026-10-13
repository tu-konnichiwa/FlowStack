# API consumer review

Reviewed as a Swift 6 app developer importing only `FlowStack`, its README, and
the public package product. `Examples/Example` is an Xcode iOS app that imports
FlowStack from this checkout through a local package dependency. It does not use
`@testable import FlowStack`. `Tests/FlowStackTests/READMEExampleTests.swift`
compiles the README quick start. The examples have no external service dependency.

## Findings repaired

| Friction observed | Consumer impact | Change |
| --- | --- | --- |
| `Dialog` was a required generic even when no app dialog existed | Boilerplate model and lost type inference for simple navigation | Added uninhabited `FlowNoDialog`; a production dialog still uses an app-owned model |
| Host required `AnyView` for custom dialog content | Consumers erased a type at the API edge | Added generic SwiftUI `@ViewBuilder` overloads and retained old overloads |
| Missing stack targets and `popTo` routes returned false without a reason | Logs could not explain rejected navigation; stale IDs were difficult to recover from | Commands record `invalidTarget`, `routeNotFound`, and `invalidPresentationStyle`; successful observers run only after an applied outcome |
| `setRoot(... refreshIfSameRoute: false)` still recreated root identity | App state could not be preserved for equal-root path restoration | Preserve root and stack IDs on the explicit opt-out |
| Observer argument named `previousStacks` contained new state | Consumers could not inspect a stable pre-action state | Record and deliver the captured pre-action snapshot |
| Async gates ran before queue acquisition | Concurrent requests could validate stale state or overtake in commit order | Evaluate gate and commit inside one FIFO turn; revalidate explicit stack targets on commit |
| Cancelled waiters could remain suspended; same-router queued work could await itself | Retained router continuations or deadlock | Remove cancelled waiters, record cancellation, detect same-turn reentrancy, and expire inherited task context when a turn ends |
| Tab lookup used preconditions even for parsed IDs | A deep link with an unknown tab could terminate the process | Added optional lookup and Boolean safe selection |
| Dialog policies existed in both routers | A policy fix could diverge between single-stack and tab routing | Moved policy into one shared internal state model while preserving observable publication for queue-only changes |
| Dialog renderer was attached only to the root presenter | A global alert/toast could appear behind a modal | Host renderer at the active stack, including nested presentation stacks |
| Presentation callbacks resolved array indexes later | A stale SwiftUI dismissal could remove a replacement modal | Capture stack identity and verify it still exists |
| Default struct route ID could recurse through RouteHashable | A seemingly valid route could overflow during equality or hashing | Read an explicit `id` child before fallback and add a regression test |
| Route fallback diagnostic was mutable global state without synchronization | Concurrent configuration could race | Protect configuration with a lock and document that the reflection fallback is prototype-only |
| Lowering history limit only took effect on the next command | Removed history kept payloads/captures longer than requested | Trim immediately when changing a positive cap |

The protected inner model is a Foundation-only reducer, appropriate to a UI
navigation library. SwiftUI hosts own bindings/rendering; `FlowRouter` owns
MainActor commands, snapshots, guards, and history. No app Domain/UseCase layers
were added to the library because consumers own those decisions.

The Example app covers independent Shop and Saved tab stacks, catalog → product
push navigation, cart and checkout modal stacks, an async sign-in gate, global
alert rendering, and nested address navigation. The app owns its demo session,
cart state, URL policy, and persistence.

## Remaining friction and release work

| Priority | Missing / improvement | Why it matters | Recommended action | Complexity / timing |
| --- | --- | --- | --- | --- |
| P1 | New `FlowOperationOutcome` cases make exhaustive source switches require updates | A library may emit these cases at runtime even when an old client compiled against its old sources | Cut a major version with a migration note, or design a future nonbreaking diagnostic result API before broader adoption. This checkout publishes no tag. | Low now; required before release |
| P1 | Native gesture, alert placement, iOS presentation behavior, and accessibility were not observed in a real rendered window/device | State tests cannot prove SwiftUI's platform presentation and gesture lifecycle | Run the Example app on supported iOS versions and add focused UI tests for modal dismiss, nested presentation, tab selection, and dialog queue dismissal. | Medium; before a production release |
| P1 | Current environment tested one Swift 6.3 Xcode toolchain | The manifest requests Swift tools 6.0, but compatibility with every Swift 6.0 compiler is not established by this run | Add a supported-Xcode matrix if Swift 6.0 is a promised compiler floor; otherwise state the tested Xcode range. | Low to medium; release decision |
| P2 | `Bool` plus mutable `operationHistory.last` is awkward for per-call diagnosis under concurrent commands | Another command may update history before a caller inspects the latest record | Consider an additive command result carrying command ID and rejection reason; keep existing Bool methods for source compatibility. Do not expand before consumers ask for correlation. | Medium; defer |
| P2 | Router routes and snapshots are not durable serialization formats | Closures, transient view state, and library-generated screen IDs are app-specific | Define app-owned URL/Codable mapping and validate restored values against app rules when adding deep links or restoration. | Low; as needed |
| P2 | No visible method to compose multiple independent style transforms | Calling the same style helper twice replaces the prior closure | Compose transformations in one closure today; consider a named composition helper if real consumers need modular style packages. | Low; defer |
| P3 | History is in-memory diagnostic retention only | Long-running flows may want metrics/export while avoiding payload retention | If demanded, add a redacted event sink that excludes route payloads by default; do not make history a persistence layer. | Medium; defer |
| P3 | No release automation/changelog workflow is configured | Versioning and migration policy otherwise rely on manual steps | Add changelog generation, tags, and package release checks when repository release ownership is known. | Medium; defer |

## Validation evidence

- Library behavior tests cover routing, target rejection, root identity, history,
  dialog parity, safe tab input, FIFO async gates, cancellation, reentrancy,
  native binding lifetime, and route payload retention.
- The README quick start compiles as a public consumer view.
- The Example Xcode app is a realistic consumer integration linked to the local
  FlowStack package product.
- `Scripts/validate.sh` runs library tests, a Release build, an iOS 16 Simulator
  library build, and builds the Example app.
- A native app window screenshot/interaction and device-native gestures remain
  unverified; compilation and state/integration tests are not visual validation.
