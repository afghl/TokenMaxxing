# TokenMaxxing Agent Guide

## Purpose

This file is the operating guide for coding agents working in this repository. Keep it short, concrete, and executable. Prefer durable project conventions over temporary task notes.

TokenMaxxing is a native SwiftUI app backed by a reusable Swift package. The app scans local coding-agent and model-provider logs, normalizes them into harness-neutral session models, and presents token usage, cost, cache hit rate, provider/model usage, and session history.

Primary target: macOS. Treat iOS support as optional unless the task explicitly asks for it.

Do not rename the product, schemes, package, or targets just to normalize spelling. Preserve the existing `TokenMaxxing` naming unless the user explicitly asks for a rename.

## Commands

Run package tests after changing core package code:

```sh
swift test --package-path Packages/TokenMaxxingCore
```

Inspect Xcode project schemes:

```sh
xcodebuild -list -project TokenMaxxing.xcodeproj
```

Build the macOS app after changing app targets, SwiftUI wiring, resources, package integration, or project settings:

```sh
xcodebuild -project TokenMaxxing.xcodeproj -scheme TokenMaxxing -destination 'platform=macOS' build
```

Build the iOS app only when iOS-specific wiring changes and the task explicitly requires it. Prefer a concrete installed simulator if one is available:

```sh
xcodebuild -project TokenMaxxing.xcodeproj -scheme 'TokenMaxxing iOS' -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Architecture

Use a lightweight SwiftUI + core-package architecture. Keep dependencies one-way and keep business logic out of views.

```text
SwiftUI View
    -> Feature ViewModel / Presentation State, when needed
    -> App State / Store, when shared state is needed
    -> Core UseCase
    -> Core Domain Model / Domain Service
    -> Repository protocol
    -> Infrastructure implementation
```

Rules:

* Core package code must not import `SwiftUI`, `AppKit`, `UIKit`, or app lifecycle APIs.
* SwiftUI views may render core value models directly. Do not create a ViewModel merely to pass through fields from `Session`, `Turn`, `Message`, or another domain value.
* Add a ViewModel or presentation-state type when a screen owns loading state, error state, search text, filters, sorting, date ranges, selected rows, navigation state, chart/table DTOs, debouncing, cancellation, or async orchestration.
* App-wide observable state belongs in the app target, not the core package, unless there is a clear reusable non-UI reason.
* Prefer `@Observable` for app/feature state when the deployment target supports Observation.
* Do not make UseCases observable. A UseCase is an application workflow, not UI state.
* Domain Services should be pure business calculations. UseCases may orchestrate repositories, importers, and domain services.
* Repositories are protocol boundaries. Infrastructure types implement those protocols for the filesystem, local databases, network APIs, or provider-specific formats.

## Code Organization

Prefer feature-based UI organization and responsibility-based core organization. The map below is a target convention, not a reason to perform broad file moves during unrelated tasks.

```text
TokenMaxxing/
  App/                         # App entry point, scene setup, dependency wiring.
    TokenMaxxingApp.swift
    AppEnvironment.swift

  AppState/                    # Shared observable state used across features.
    UsageStore.swift

  Features/                    # Feature-based SwiftUI screens and presentation state.
    <FeatureName>/
      <FeatureName>View.swift
      <FeatureName>ViewModel.swift
      <FeatureName>Models.swift

  SharedUI/                    # Reusable UI pieces that are not tied to one feature.
    Components/
    Charts/
    Formatters/

Packages/
  TokenMaxxingCore/            # Reusable core package; keep it UI-platform independent.
    Sources/TokenMaxxingCore/
      Models/                  # Domain entities and value objects.
      Services/                # Pure domain calculations.
      UseCases/                # Application workflows / user-intent actions.
      Repositories/            # Data access protocols and persistence boundaries.
      Importers/               # Adapters that parse external logs into domain models.

    Tests/TokenMaxxingCoreTests/
```

When modifying the current codebase:

* Put reusable logic in `Packages/TokenMaxxingCore`.
* Put SwiftUI screens under `TokenMaxxing/Features/<FeatureName>`.
* Put shared observable app state under `TokenMaxxing/AppState`.
* Put reusable UI under `TokenMaxxing/SharedUI`.
* Prefer small focused files over large mixed-purpose files.
* Do not add a new package target until there is a real module boundary.
* Do not move existing files, rename targets, rename schemes, or restructure folders unless the task explicitly requires it.

## Layer Naming

Use names that describe architectural responsibility:

* Model: `Session`, `Turn`, `Message`, `TokenUsage`, `Provider`, `ModelPricing`.
* Domain Service: `CostCalculator`, `UsageAggregator`, `CacheHitRateCalculator`.
* UseCase: `ScanSessionsUseCase`, `ImportSessionsUseCase`, `BuildDashboardUseCase`.
* Repository protocol: `SessionRepository`, `PricingRepository`, `LogSourceRepository`.
* Infrastructure implementation: `FileSystemLogSourceRepository`, `SQLiteSessionRepository`, provider-specific API clients.
* Importer: `CodexSessionImporter`, `ClaudeSessionImporter`, `CursorSessionImporter`.
* ViewModel / Presentation State: `DashboardViewModel`, `SessionListViewModel`, feature-local chart/table row models.
* View: `DashboardView`, `SessionListView`, `SessionDetailView`.

Prefer `UseCase` for user-intent workflows. Prefer `Service` for pure business rules. Prefer `Repository` for data access boundaries. Prefer `Importer` for external log-format adapters.

## Current Domain Language

* `Session`: one coding harness session.
* `Turn`: one user message and the work until the next user message or completion marker.
* `Message`: a normalized message/event inside a session or turn.
* `SessionImporter`: an adapter-style interface that imports external local filesystem logs into normalized `Session` objects.

Codex support belongs in `CodexSessionImporter`. Future Claude Code, Cursor, opencode, and provider API support should be separate importer implementations that return the same harness-neutral domain models.

## Swift Style

* Use Swift 5.9-compatible syntax unless the project updates its toolchain.
* Prefer value types for domain models.
* Prefer dependency injection through initializers.
* Prefer `async/await` over callback-based APIs when adding asynchronous work.
* Keep core code deterministic and testable. Inject clocks, filesystem roots, dates, repositories, and configuration when behavior depends on environment.
* Avoid third-party dependencies unless the user approves them.
* Keep comments short and only where they clarify non-obvious logic.
* Do not hide parsing rules, aggregation rules, or cost rules inside SwiftUI views.
* Keep platform-specific APIs in app or infrastructure code, not in domain models or pure services.

## Domain Rules

* Treat raw harness logs as adapter input, not as domain models.
* Keep `Session`, `Turn`, and `Message` harness-neutral.
* Token usage fields are metrics attached to domain objects, not the root of the domain model.
* For Codex token statistics, prefer cumulative `token_count.total_token_usage` snapshots and derive deltas by subtraction.
* Do not double-count `reasoningOutputTokens`; it is a breakdown of output tokens, not an additional total.
* A Codex turn normally starts at the first `event_msg.user_message` inside an `event_msg.task_started` window and ends at that window's `event_msg.task_complete`, if present.
* Codex Desktop Steer/interruption input may add another `event_msg.user_message` before the current `task_complete` without a new `task_started`; treat that as a message inside the current turn, not as a new turn boundary.

## Testing

* Add or update package tests for importer, parser, aggregation, cost calculation, and use-case behavior.
* Use tiny JSONL fixtures in tests instead of depending on the developer's real `~/.codex`, `~/.claude`, or `~/.cursor` data.
* Keep tests deterministic by injecting temporary roots, fixed dates, fixed clocks, and fixture files.
* Prefer testing core package behavior before UI behavior.
* After model, service, importer, repository, or use-case changes, run:

```sh
swift test --package-path Packages/TokenMaxxingCore
```

* After app target, SwiftUI integration, resource, or project-setting changes, build the macOS app:

```sh
xcodebuild -project TokenMaxxing.xcodeproj -scheme TokenMaxxing -destination 'platform=macOS' build
```

## Safety and Boundaries

* Do not read, print, or expose private user logs unless the task explicitly requires inspecting local logs.
* Do not copy real private log contents into tests, fixtures, docs, screenshots, or final responses.
* Do not write into `~/.codex`, `~/.claude`, or `~/.cursor` during tests.
* Do not stage, commit, push, rename schemes, rewrite project structure, or add production dependencies unless explicitly asked.
* The worktree may already contain user changes; preserve them.
* Prefer narrow, task-scoped edits over broad refactors.
* If a requested change conflicts with existing project conventions, explain the conflict before changing the convention.

## Done Criteria

Before finishing a code task:

* Run the most relevant test or build command for the files changed.
* If a command cannot be run, say why.
* Summarize what changed and where.
* Summarize validation performed.
* Call out risky assumptions, skipped validation, or follow-up work.

## Maintaining This File

Update `AGENTS.md` when you discover a durable project convention, command, gotcha, domain rule, or repeated agent failure pattern that future agents should know before editing the code.

Do not add task-specific notes, temporary plans, or stale TODOs to this file.