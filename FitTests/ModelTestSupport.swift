import Foundation
import SwiftData
import XCTest
@testable import Fit

/// Helpers for the model-level tests that DO need a live `ModelContext`
/// (importer, merge, persistence). Unlike the context-free `Fixture` helpers in
/// `TestSupport.swift`, these run against a real SwiftData store.
///
/// CRITICAL: there is exactly ONE `ModelContainer` in the test process —
/// `PersistenceController.testContainer` — shared by the host app and every test
/// (a second container for the same schema crashes the XCTest host; this is the
/// F16/F30 constraint). So tests here:
///   - all share the same in-memory store (it is NOT reset between tests), and
///   - therefore use fresh `UUID()`s per test and assert ONLY on their own ids,
///     never on global counts or an "empty" store.
@MainActor
enum ModelTestSupport {

    /// A fresh `ModelContext` on the single shared test container. Each context is
    /// independent but reads/writes the same underlying in-memory store, so keep
    /// ids unique per test.
    static func makeContext() -> ModelContext {
        ModelContext(PersistenceController.testContainer)
    }
}
