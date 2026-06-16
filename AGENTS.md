# TokenMaxxing Agent Guide

## Project Shape

TokenMaxxing is a SwiftUI app backed by a local Swift package.

- `Packages/TokenMaxxingCore` is the reusable domain/core layer. Keep domain
  models, importers, parsing, aggregation, and statistics here.
- `TokenMaxxing/App` contains app entry points and lifecycle wiring.
- `TokenMaxxing/Features` contains SwiftUI feature views.
- Keep UI and platform glue out of `TokenMaxxingCore` unless the package
  explicitly needs it.

The current domain language is:

- `Session`: one coding harness session.
- `Turn`: one user message and the work until the next user message or
  completion marker.
- `Message`: a normalized message/event inside a session or turn.
- `SessionImporter`: an adapter-style interface that imports external local
  filesystem logs into normalized `Session` objects.

Codex support belongs in `CodexSessionImporter`; future Claude Code and
opencode support should be separate importer implementations that return the
same domain models.

## Commands

Run package tests after changing `Packages/TokenMaxxingCore`:

```sh
swift test --package-path Packages/TokenMaxxingCore
```

Inspect project schemes:

```sh
xcodebuild -list -project TokenMaxxing.xcodeproj
```

Build the macOS app when app target or SwiftUI wiring changes:

```sh
xcodebuild -project TokenMaxxing.xcodeproj -scheme TokenMaxxing -destination 'platform=macOS' build
```

Build the iOS app only when iOS-specific wiring changes. Prefer a concrete
installed simulator if one is available:

```sh
xcodebuild -project TokenMaxxing.xcodeproj -scheme 'TokenMaxxing iOS' -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## Code Organization

- Put reusable logic in `Packages/TokenMaxxingCore`.
- Put SwiftUI screens under `TokenMaxxing/Features/<FeatureName>`.
- Prefer small focused files over large mixed-purpose files.
- Do not add a new package target until there is a real boundary. The current
  package can hold domain models and importer implementations for now.
- Do not move existing files or rename schemes unless the task explicitly
  requires it.

## Swift Style

- Use Swift 5.9-compatible syntax unless the project updates its toolchain.
- Prefer value types for domain models.
- Keep package code independent of SwiftUI, AppKit, UIKit, and app lifecycle
  APIs unless a target is explicitly UI-facing.
- Prefer `async/await` over callback-based APIs when adding asynchronous work.
- Avoid third-party dependencies unless the user approves them.
- Keep comments short and only where they clarify non-obvious logic.

## Domain Rules

- Treat raw harness logs as adapter input, not as domain models.
- Keep `Session`, `Turn`, and `Message` harness-neutral.
- Token usage fields are metrics attached to domain objects, not the root of
  the domain model.
- For Codex token statistics, prefer cumulative `token_count.total_token_usage`
  snapshots and derive deltas by subtraction.
- Do not double-count `reasoningOutputTokens`; it is a breakdown of output
  tokens, not an additional total.
- A Codex turn normally starts at the first `event_msg.user_message` inside an
  `event_msg.task_started` window and ends at that window's
  `event_msg.task_complete`, if present.
- Codex Desktop Steer/interruption input may add another
  `event_msg.user_message` before the current `task_complete` without a new
  `task_started`; treat that as a message inside the current turn, not as a new
  turn boundary.

## Testing

- Add or update package tests for importer, parser, and aggregation behavior.
- Use tiny JSONL fixtures in tests instead of depending on the developer's real
  `~/.codex` data.
- Keep tests deterministic by injecting temporary roots, fixed dates, and
  fixture files.
- After model or importer changes, run:

```sh
swift test --package-path Packages/TokenMaxxingCore
```

## Safety

- Do not read or expose private user logs in test fixtures.
- Do not write into `~/.codex` during tests.
- Do not stage, commit, or push unless explicitly asked.
- The worktree may already contain user changes; preserve them.

## Maintaining This File

Update `AGENTS.md` when you discover a project convention, command, gotcha, or
domain rule that future agents should know before editing the code.
