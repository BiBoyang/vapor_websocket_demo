@scope:global:v1



# ⚠️ Mandatory Output Rules (Canary Test)
Before the end of every response, you must:
1. Scan all @scope:xxx markers in the context (including version numbers such as v1).
2. Output the signature on a **separate line** at the very end of the response:
   >>>AGENTS:[scope1,scope2,...]|STATUS:[OK|MISSING]
3. If STATUS is MISSING, append the warning: "⚠️ Context truncated: part of AGENTS.md was not loaded"




# Swift Code Style Guidelines

## Verify Build
- You must build with `xcodebuild` on `Example/Example.xcworkspace` with scheme `Example` and target `Mac Catalyst`.
- You must use `xcbeautify` to save your context and tokens.

## Core Style
- **Indentation**: 4 spaces
- **Braces**: Opening brace on same line
- **Spacing**: Single space around operators and commas
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Trailing whitespace**: No trailing spaces
- **Line length**: Wrap long lines at logical boundaries
- **Semicolons**: Avoid unless required for multiple statements
- **Imports**: Group by system, third-party, and local modules

## Formatting Examples
- **Functions**: Use parameter labels consistently and favor multi-line signatures for long parameter lists
- **Closures**: Prefer trailing closure syntax when it improves readability
- **Collections**: Use trailing commas in multi-line literals
- **Conditionals**: Prefer early returns and guard statements over deeply nested ifs

## File Organization
- Logical directory grouping
- PascalCase files for types, `+` for extensions
- Modular design with extensions
- One primary type per file
- Separate extensions by responsibility and protocol conformance

## Modern Swift Features
- **@Observable macro**: Replace `ObservableObject`/`@Published`
- **Swift concurrency**: `async/await`, `Task`, `actor`, `@MainActor`
- **Result builders**: Declarative APIs
- **Property wrappers**: Use line breaks for long declarations
- **Opaque types**: `some` for protocol returns
- **Actors**: Use actors for shared mutable state
- **Async sequences**: Prefer AsyncSequence for streaming data
- **Structured concurrency**: Avoid detached tasks unless required

## Code Structure
- Early returns to reduce nesting
- Guard statements for optional unwrapping
- Single responsibility per type/extension
- Value types over reference types
- Prefer pure functions for transformation-heavy logic
- Avoid static mutable state
- Keep view logic minimal and delegate business logic to dedicated types

## Error Handling
- `Result` enum for typed errors
- `throws`/`try` for propagation
- Optional chaining with `guard let`/`if let`
- Typed error definitions
- Prefer domain-specific error enums over generic errors
- Avoid swallowing errors; handle or rethrow explicitly

## API Design
- Use clear, specific names and avoid abbreviations
- Prefer default parameters for optional configuration
- Favor value semantics in public APIs
- Keep functions focused on a single responsibility
- Prefer immutability for public properties

## Architecture
- Avoid using protocol-oriented design unless necessary
- Dependency injection over singletons
- Composition over inheritance
- Factory/Repository patterns
- Define module boundaries and keep cross-module dependencies explicit
- Use coordinators or routers for navigation flow
- Centralize configuration and environment handling

## Debug Assertions
- Use `assert()` for development-time invariant checking
- Use `assertionFailure()` for unreachable code paths
- Assertions removed in release builds for performance
- Precondition checking with `precondition()` for fatal errors
- Use meaningful failure messages to aid diagnosis

## Memory Management
- `weak` references for cycles
- `unowned` when guaranteed non-nil
- Capture lists in closures
- `deinit` for cleanup
- Avoid retaining self in async contexts without need
- Use autorelease pools for large temporary allocations

## Testing
- Prefer deterministic tests with explicit inputs
- Name tests with behavior-driven style
- Use test doubles sparingly and keep them simple
- Keep UI tests focused on critical flows

## Localization
- Use localized string keys for user-facing text
- Avoid hard-coded text in UI components
- Prefer string interpolation with localized format strings

