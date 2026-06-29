import Foundation
import XCTest
@testable import Fit

/// Ties `data_dictionary.md` (F29) to the export **contract** the same way
/// `ExportContractTests` (F28) locks the CSV headers: the dictionary must
/// document *every* column the CSV exporters actually emit, and *every* raw value
/// of the enums the columns use. If a column is added/renamed or an enum case is
/// added, this suite fails until the dictionary is updated — so the doc cannot
/// silently drift from the data it describes.
///
/// Headers are extracted exactly the way F28 does it — `CSVExporter.<file>(empty)`
/// parsed with the real `CSVParser` — so the two suites agree on what "the
/// columns" are. Hermetic and context-free: an empty, hand-built `ExportDataSet`,
/// no `ModelContext` (per the F16 test-host crash lesson).
final class ExportSchemaTests: XCTestCase {

    // MARK: - Helpers

    /// An empty data set — headers are emitted regardless of rows (mirrors F28).
    private func emptyDataSet() -> ExportDataSet {
        ExportDataSet(
            generatedAt: Date(),
            workouts: [],
            sets: [],
            exercises: [],
            exerciseAliases: [],
            healthWorkouts: [],
            bodyWeightEntries: [],
            sleepEntries: [],
            journalEntries: []
        )
    }

    /// The header row of one CSV document, via the real parser (as F28 does).
    private func header(_ document: String) -> [String] {
        CSVParser.parse(document).first ?? []
    }

    /// Every column emitted across every per-file CSV builder.
    private func allEmittedColumns() -> [String] {
        let data = emptyDataSet()
        let documents = [
            CSVExporter.workouts(data),
            CSVExporter.sets(data),
            CSVExporter.exercises(data),
            CSVExporter.exerciseAliases(data),
            CSVExporter.healthWorkouts(data),
            CSVExporter.heartRateSummary(data),
            CSVExporter.bodyWeight(data),
            CSVExporter.sleep(data),
            CSVExporter.journalEntries(data)
        ]
        return documents.flatMap { header($0) }
    }

    // MARK: - Tests

    func testMarkdownIsNonEmpty() {
        XCTAssertFalse(ExportSchema.markdown().isEmpty, "Data dictionary must not be empty.")
    }

    /// Every column emitted by the CSV exporters must be documented in the dict.
    func testDocumentsEveryEmittedColumn() {
        let markdown = ExportSchema.markdown()
        let columns = allEmittedColumns()
        XCTAssertFalse(columns.isEmpty, "Sanity: exporters should emit some columns.")
        for column in columns {
            XCTAssertTrue(
                markdown.contains(column),
                "data_dictionary.md does not document the emitted column `\(column)`."
            )
        }
    }

    /// Every raw value of every enum surfaced in the CSVs must appear in the dict.
    func testDocumentsEveryEnumRawValue() {
        let markdown = ExportSchema.markdown()
        assertAllRawValuesDocumented(WeightMode.self, in: markdown)
        assertAllRawValuesDocumented(RepsLeft.self, in: markdown)
        assertAllRawValuesDocumented(FormQuality.self, in: markdown)
        assertAllRawValuesDocumented(Limiter.self, in: markdown)
        assertAllRawValuesDocumented(PainSeverity.self, in: markdown)
        assertAllRawValuesDocumented(PainLocation.self, in: markdown)
        assertAllRawValuesDocumented(RecordSource.self, in: markdown)
        assertAllRawValuesDocumented(WorkoutGoal.self, in: markdown)
        assertAllRawValuesDocumented(WorkoutLocation.self, in: markdown)
        assertAllRawValuesDocumented(Soreness.self, in: markdown)
        assertAllRawValuesDocumented(PainToday.self, in: markdown)
        assertAllRawValuesDocumented(SleepQuality.self, in: markdown)
        assertAllRawValuesDocumented(FoodTiming.self, in: markdown)
        assertAllRawValuesDocumented(Caffeine.self, in: markdown)
        assertAllRawValuesDocumented(ExerciseCategory.self, in: markdown)
        assertAllRawValuesDocumented(Equipment.self, in: markdown)
        assertAllRawValuesDocumented(MovementPattern.self, in: markdown)
        assertAllRawValuesDocumented(MuscleGroup.self, in: markdown)
        assertAllRawValuesDocumented(JournalEntryType.self, in: markdown)
        assertAllRawValuesDocumented(DataSource.self, in: markdown)
    }

    /// The 0–5 scale labels (effort/energy/stress) must all appear.
    func testDocumentsScaleLabels() {
        let markdown = ExportSchema.markdown()
        for value in 0...5 {
            XCTAssertTrue(markdown.contains(EffortScale.label(for: value)),
                "Missing effort label for \(value): \(EffortScale.label(for: value))")
            XCTAssertTrue(markdown.contains(EnergyScale.label(for: value)),
                "Missing energy label for \(value): \(EnergyScale.label(for: value))")
            XCTAssertTrue(markdown.contains(StressScale.label(for: value)),
                "Missing stress label for \(value): \(StressScale.label(for: value))")
        }
    }

    /// The derived-column names must be documented (they are emitted columns, but
    /// pin them explicitly since the dictionary explains their formulas).
    func testDocumentsDerivedColumns() {
        let markdown = ExportSchema.markdown()
        for column in ["effective_load_kg", "volume_kg", "estimated_1rm_kg", "superset_group"] {
            XCTAssertTrue(markdown.contains(column), "Derived column `\(column)` not documented.")
        }
    }

    // MARK: - Private

    private func assertAllRawValuesDocumented<T: DisplayableOption>(
        _ type: T.Type,
        in markdown: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) where T.AllCases: Sequence {
        for option in type.allCases {
            XCTAssertTrue(
                markdown.contains(option.rawValue),
                "data_dictionary.md does not document raw value `\(option.rawValue)` of \(type).",
                file: file, line: line
            )
        }
    }
}
