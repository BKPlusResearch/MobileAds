# MobileAds iOS App Constitution

## Core Principles

### I. Clean Architecture (NON-NEGOTIABLE)

The application MUST follow Clean Architecture with strict three-layer separation:

- **Domain Layer** (`MobileAds/Domain/`): Contains business logic, entities, repository protocols, and use cases. MUST be completely independent of frameworks and platforms.
- **Data Layer** (`MobileAds/Data/`): Implements repository protocols from Domain layer. Handles API calls, Realm operations, and data persistence.
- **Presentation Layer** (`MobileAds/Presentation/`): Manages UI/UX using MVVM pattern with Coordinator for navigation. Coordinates between View, ViewModel, and UseCase.

**Rationale**: Clear separation of concerns enables testability, maintainability, and independence from external frameworks. Business logic remains platform-agnostic.

### II. Dependency Flow (NON-NEGOTIABLE)

Dependencies MUST flow inward only: Presentation → Domain → Data → External Sources. NEVER reverse this flow. Presentation layer depends on Domain layer, Domain layer depends on Data layer. Data layer fetches from external sources (API, Realm, UserDefaults).

**Rationale**: Inward dependency flow ensures business logic remains independent and testable. Violations create circular dependencies and break architectural boundaries.

### III. Naming Conventions

All code MUST follow strict naming conventions:

- **Types** (Classes, Structs, Enums, Protocols): PascalCase, descriptive full words, 3-40 characters (warning), 50 characters (error)
- **Variables and Properties**: camelCase, descriptive names, 2-50 characters, boolean properties start with `is`, `has`, `can`, `should`
- **Functions and Methods**: camelCase, verb phrases for actions, noun phrases for return values
- **Constants**: camelCase for local, PascalCase for global
- **File Names**: Match main type name, PascalCase, one main type per file
- **ViewModels**: Always use `[Feature]ViewModel` or `[Feature]VM` suffix (be consistent within project)
- **ViewControllers**: Always use `[Feature]VC` or `[Feature]ViewController` suffix (be consistent within project)
- **Coordinators**: Always use `[Feature]Coordinator` suffix
- **Repositories**: Protocol `[Entity]Repository`, Implementation `[Entity]RepositoryImpl`
- **UseCases**: Format `[Verb][Entity]UseCase` or `[Action]UseCase`

**Rationale**: Consistent naming improves code readability, maintainability, and reduces cognitive load when navigating the codebase.

### IV. Code Formatting

Code MUST adhere to formatting standards:

- **Indentation**: 4 spaces (not tabs)
- **Line Length**: Maximum 120 characters (warning), 150 characters (error)
- **Spacing**: Maximum 2 empty lines between code blocks, single space around operators and after commas, no space before colons in type annotations
- **Braces**: Opening brace on same line as declaration, closing brace on own line
- **Trailing Closures**: Use trailing closure syntax when closure is last parameter

**Rationale**: Consistent formatting reduces visual noise, improves code review efficiency, and ensures team-wide code style uniformity.

### V. Type Safety and Optional Handling

Optionals MUST be handled safely. Use `?` for optional types, avoid `!` (force unwrapping) unless absolutely necessary. Prefer `guard let` over `if let` for early returns. Use `if let` for optional binding when early return is not needed. Use nil-coalescing operator `??` when appropriate.

**Rationale**: Safe optional handling prevents runtime crashes and makes code intent explicit. Force unwrapping introduces unnecessary risk.

### VI. Function Design

Functions MUST be focused and concise:

- Keep functions shorter than 30 lines
- Break long functions into smaller, focused functions
- Each function MUST have a single responsibility
- Always specify return type for public functions
- Use descriptive parameter names with appropriate labels

**Rationale**: Small, focused functions are easier to test, understand, and maintain. Single responsibility principle reduces complexity and improves code quality.

### VII. Code Organization

Code MUST follow standard file structure:

1. Imports (grouped: System frameworks → Third-party libraries → Project modules)
2. Type declaration
3. Properties (grouped by access level: private, internal, public)
4. Initializers
5. Lifecycle methods
6. Public methods
7. Private methods
8. Extensions (if any)

Use `// MARK: - Section Name` comments to organize code sections. Group related properties and methods together.

**Rationale**: Consistent organization makes code navigation predictable and reduces time spent locating functionality.

### VIII. Swift-Specific Patterns

Swift-specific features MUST be used correctly:

- **Closures**: Use `[weak self]` or `[unowned self]` in closures that capture `self` to prevent retain cycles
- **Extensions**: Use extensions to organize code within files, group related functionality, and handle protocol conformance
- **Enums**: Use enums for related constants, raw values when appropriate, associated values for complex cases
- **Access Control**: Use most restrictive access level (default to `private` or `fileprivate` for internal implementation)

**Rationale**: Proper use of Swift features prevents memory leaks, improves code organization, and leverages language strengths.

### IX. Constants and Localization

Magic numbers MUST be extracted into named constants. User-facing strings MUST NEVER be hardcoded - always use `.localized` extension. Use constants for internal strings (keys, identifiers). Group related constants together.

**Rationale**: Named constants improve readability and maintainability. Localization ensures internationalization support and prevents hardcoded text scattered throughout code.

### X. Error Handling

Error handling MUST be explicit and meaningful:

- Use custom error types when appropriate, conforming to `Error` protocol
- Provide meaningful error messages
- Use `do-catch` for synchronous error handling
- Use `Result` type for operations that can fail
- Handle errors in RxSwift using `catchError` operator

**Rationale**: Explicit error handling improves debugging, user experience, and system reliability. Meaningful errors reduce support burden.

### XI. Code Quality

Code quality standards MUST be maintained:

- Remove unused code, empty methods, unused variables, and commented-out code
- Avoid code duplication - extract common functionality into reusable methods or extensions
- Keep functions simple and focused
- Avoid deep nesting (max 3-4 levels)
- Break complex logic into smaller functions
- Use early returns to reduce nesting

**Rationale**: Clean, maintainable code reduces technical debt, improves readability, and accelerates development velocity.

## Architecture Constraints

### Module Organization

Each feature module (Onboarding, Category, Favourite, Setting, etc.) MUST be organized across all three layers:

- **Domain**: `MobileAds/Domain/Entities/[Feature]/`, `MobileAds/Domain/Repositories/[Feature]/`, `MobileAds/Domain/UseCases/[Feature]/`
- **Data**: `MobileAds/Data/Repositories/[Feature]/`
- **Presentation**: `MobileAds/Presentation/[Feature]/` containing `[Feature]VC.swift`, `[Feature]VM.swift`, `[Feature]Coordinator.swift`, and optional `SubViews/` directory

### Helper Layer

The `MobileAds/Helper/` module contains shared services and utilities:
- Navigation services (Coordinators, NavigationService)
- System services (PhotoLibraryService, VideoDownloadService)
- Managers (UserDefaultsManager, LanguageManager)
- Extensions (String+Localized, UIView+Extension)
- Base classes (BaseVC, ViewModel protocol)

Feature-specific code MUST NOT be placed in Helper. Helper contains only cross-cutting concerns.

### Design Patterns

- **UseCase Pattern**: Business logic MUST be encapsulated in use cases. Use cases orchestrate repository operations and contain business validation. Return RxSwift observables (Single, Completable, Observable).
- **Repository Pattern**: Data access MUST be abstracted through repository protocols in Domain layer, with implementations in Data layer. Repository protocols return RxSwift observables.
- **MVVM Pattern**: Presentation layer MUST use MVVM pattern with ViewModels implementing Input/Output transform pattern. ViewModels coordinate between View and UseCase.
- **Coordinator Pattern**: Navigation logic MUST be handled by Coordinators, not ViewControllers. Each feature has its own Coordinator managing navigation flow.
- **Dependency Injection**: NEVER create instances directly. Use ServiceContainer for dependency injection. All dependencies MUST be injected through initializers.

### ViewModel Pattern

ViewModels MUST implement the Input/Output transform pattern:

```swift
class SomeViewModel: ViewModel {
    struct Input {
        let trigger: Signal<Void>
    }
    
    struct Output {
        let result: Driver<SomeType>
    }
    
    func transform(input: Input) -> Output {
        // Transform logic
    }
}
```

ViewModels MUST NOT import UIKit. ViewModels contain only business logic and reactive transformations.

### Coordinator Pattern

Coordinators MUST:
- Implement the Coordinator protocol
- Manage child coordinators lifecycle
- Handle all navigation logic
- Create and configure ViewControllers and ViewModels
- Use ServiceContainer for dependency resolution

ViewControllers MUST NOT navigate directly. All navigation MUST go through Coordinators.

## Development Workflow

### Swift Version

- Use Swift 5.5+ syntax
- Follow modern Swift conventions

### Import Organization

- Remove unused imports
- Group imports logically: System frameworks (UIKit, Foundation) → Third-party libraries (RxSwift, RxCocoa, SnapKit, etc.) → Project modules

### Documentation

- Use `///` for documentation comments on public APIs
- Include parameter descriptions and return values
- Use `//` for inline comments explaining "why" not "what"
- Keep comments up to date with code
- Remove outdated or unnecessary comments

### RxSwift Usage

- Dispose subscriptions properly using `disposed(by: disposeBag)`
- Use appropriate observable types: `Driver` for UI binding, `Signal` for one-off events, `Single` for single-value operations, `Completable` for operations without return values
- Use appropriate schedulers (observeOn, subscribeOn)
- Handle errors using `catchError` operator
- Always use `[weak self]` in closures that capture `self`

### Memory Management

- All RxSwift subscriptions MUST be disposed using `disposed(by: disposeBag)`
- Use `[weak self]` in all closures that capture `self` to prevent retain cycles
- BaseVC provides `disposeBag` for automatic cleanup
- Coordinators MUST manage child coordinator lifecycle to prevent memory leaks

## Governance

This constitution supersedes all other coding practices and style guides. All code reviews MUST verify compliance with these principles.

**Amendment Procedure**: Amendments require documentation of rationale, approval from architecture team, and migration plan for existing violations.

**Compliance Review**: All PRs/reviews must verify compliance. Complexity must be justified. Use `.cursor/rules/` files for runtime development guidance.

**Versioning Policy**: Constitution version follows semantic versioning:

- **MAJOR**: Backward incompatible governance/principle removals or redefinitions
- **MINOR**: New principle/section added or materially expanded guidance
- **PATCH**: Clarifications, wording, typo fixes, non-semantic refinements

**Version**: 2.0.0 | **Ratified**: 2026-02-05 | **Last Amended**: 2026-02-05 | **Adapted for**: MobileAds iOS App
