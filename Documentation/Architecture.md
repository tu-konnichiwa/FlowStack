# Architecture and refactoring decisions

FlowStack is a UI navigation adapter, not an application's Domain or Application
layer. App use cases should return app-owned results; a presentation coordinator
maps those results into router commands. Route payloads and UI styling belong to
the consumer. No network, persistence, dependency container, or third-party
package belongs in this library.

## Decision: soft boundary around navigation policy

Alternatives considered before implementation:

1. Add a public FlowStackCore target and a reducer/event API. This enforces imports,
   but adds packaging and public contracts that consumers do not currently need.
2. Keep one product and use an internal Foundation-only state reducer. Routers
   own MainActor observation, guards, and history; SwiftUI hosts own bindings and
   rendering. The reducer owns path, root, target, and dismissal invariants.

Choose option 2. It centralizes policy and enables device-free tests without a
new public architecture. SwiftUI and Combine stay in adapters. Dialog scheduling
uses one internal value model shared by the single-stack and tab routers.

## Decision: preserve command signatures

Alternatives:

1. Replace Bool command returns with throwing methods or a new result API.
2. Preserve Bool returns and expose failure details through operation history.

Choose option 2. Missing stack/route and invalid presentation requests return
false and receive diagnostic outcomes. Valid no-ops return true. Existing
observers retain their signature and receive the documented pre-operation state.
New outcome cases require consumers with exhaustive switches to add cases.

## Decision: serialize async validation and commit together

Alternatives:

1. Evaluate async gates concurrently and serialize only the commit. Faster gates
   can overtake earlier requests and inspect stale state.
2. Acquire a FIFO turn before running an async gate, then validate and commit.

Choose option 2. Cancellation removes waiting requests and prevents uncommitted
mutations. Cancellation after a commit does not undo it. Synchronous commands
remain immediate and can run while an async gate is suspended; the target is
validated again on commit. A task-local ownership check rejects nested queued commands on the same router
with reentrantTransition, preventing self-wait deadlocks. Use a different router
or perform the follow-up after the outer command returns. Transition delay is spacing, not animation
completion detection.

## Compatibility

Keep platform floors (iOS 16/macOS 13), Swift 6, existing router names and command
signatures, style defaults, RouteHashable fallback IDs, and history limit meaning
(positive = bounded; zero/negative = unlimited). Safe additions include a
no-dialog model, generic dialog builders, and optional tab lookup. No release tag
is created by this refactor. See ConsumerReview.md for behavior corrections and
remaining release work.
