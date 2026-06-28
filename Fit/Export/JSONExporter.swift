import Foundation

/// Builds the single nested JSON document for an export.
///
/// The `@Model` classes are deliberately NOT made `Codable`. Instead we map them
/// to plain `Codable` DTO structs here, which keeps the export schema explicit
/// and decoupled from persistence. Dates are ISO-8601 (with timezone); weights
/// are kg. Output uses `.sortedKeys` + `.prettyPrinted` for stable, diffable files.
enum JSONExporter {

    // MARK: - DTOs (export schema §12.14)

    /// Top-level document.
    struct ExportDocument: Codable {
        let export_version: String
        let schema_version: String
        let exported_at: String
        let app_version: String
        let timezone: String
        let date_range_start: String?
        let date_range_end: String?
        let units: Units
        let workouts: [WorkoutDTO]
        let exercises: [ExerciseDTO]
        let body_weight_entries: [BodyWeightDTO]
        let sleep_entries: [SleepDTO]
    }

    struct Units: Codable {
        let weight: String
    }

    struct WorkoutDTO: Codable {
        let workout_id: String
        let title: String?
        let start_time: String
        let end_time: String?
        let timezone: String
        let duration_seconds: Double?
        let is_backfilled: Bool
        let session_metadata: SessionMetadataDTO
        let sets: [SetDTO]
        let linked_health_workout: HealthWorkoutDTO?
        let journal_entries: [JournalDTO]
        let created_at: String
        let updated_at: String
    }

    struct SessionMetadataDTO: Codable {
        let goal: String?
        let location: String?
        let energy_before: Int?
        let soreness: String?
        let pain_today: String?
        let sleep_quality_subjective: String?
        let stress_level: Int?
        let food_timing: String?
        let caffeine: String?
        let body_weight_manual_kg: Double?
        let notes: String?
    }

    struct SetDTO: Codable {
        let set_id: String
        let exercise_id: String?
        let exercise_name_at_time: String
        let set_index: Int
        let timestamp: String
        let weight_mode: String
        let weight_kg: Double?
        let body_weight_kg: Double?
        let assistance_kg: Double?
        let added_weight_kg: Double?
        let effective_load_kg: Double?
        let reps: Int?
        let volume_kg: Double?
        let estimated_1rm_kg: Double?
        let effort: Int?
        let reps_left: String?
        let form_quality: String?
        let limiter: String?
        let pain_severity: String?
        let pain_location: String?
        let is_warmup: Bool
        let is_failed: Bool
        let source: String
        let notes: String?
        let created_at: String
        let updated_at: String
    }

    struct HealthWorkoutDTO: Codable {
        let health_workout_id: String
        let apple_health_uuid: String
        let workout_type: String
        let start_time: String
        let end_time: String
        let duration_seconds: Double
        let active_energy_kcal: Double?
        let total_energy_kcal: Double?
        let avg_heart_rate_bpm: Double?
        let min_heart_rate_bpm: Double?
        let max_heart_rate_bpm: Double?
        let heart_rate_sample_count: Int?
        let source_name: String?
        let source_device: String?
        let imported_at: String
    }

    struct JournalDTO: Codable {
        let entry_id: String
        let workout_id: String?
        let exercise_id: String?
        let set_id: String?
        let timestamp: String
        let entry_type: String
        let text: String
        let created_at: String
        let updated_at: String
    }

    struct ExerciseDTO: Codable {
        let exercise_id: String
        let canonical_name: String
        let category: String?
        let equipment: String?
        let movement_pattern: String?
        let default_weight_mode: String
        let primary_muscles: [String]
        let secondary_muscles: [String]
        let aliases: [AliasDTO]
        let notes: String?
        let archived: Bool
        let is_goal_exercise: Bool
        let is_favorite: Bool
        let created_at: String
        let updated_at: String
    }

    struct AliasDTO: Codable {
        let alias_id: String
        let alias_name: String
        let language: String?
        let created_at: String
    }

    struct BodyWeightDTO: Codable {
        let entry_id: String
        let timestamp: String
        let weight_kg: Double
        let source: String
        let apple_health_sample_id: String?
        let notes: String?
    }

    struct SleepDTO: Codable {
        let entry_id: String
        let date: String
        let start_time: String?
        let end_time: String?
        let duration_seconds: Double?
        let source: String
        let subjective_sleep_quality: String?
        let apple_health_sample_id: String?
        let notes: String?
    }

    // MARK: - Mapping

    private static func nilIfEmpty(_ s: String) -> String? {
        s.isEmpty ? nil : s
    }

    private static func map(_ s: WorkoutSet) -> SetDTO {
        SetDTO(
            set_id: s.id.uuidString,
            exercise_id: s.exercise?.id.uuidString,
            exercise_name_at_time: s.exerciseNameAtTime,
            set_index: s.setIndex,
            timestamp: ExportFormatting.iso(s.timestamp),
            weight_mode: s.weightMode.rawValue,
            weight_kg: s.weightKg,
            body_weight_kg: s.bodyWeightKg,
            assistance_kg: s.assistanceKg,
            added_weight_kg: s.addedWeightKg,
            effective_load_kg: s.effectiveLoadKg,
            reps: s.reps,
            volume_kg: s.volumeKg,
            estimated_1rm_kg: s.estimatedOneRepMaxKg,
            effort: s.effort,
            reps_left: s.repsLeft?.rawValue,
            form_quality: s.formQuality?.rawValue,
            limiter: s.limiter?.rawValue,
            pain_severity: s.painSeverity?.rawValue,
            pain_location: s.painLocation?.rawValue,
            is_warmup: s.isWarmup,
            is_failed: s.isFailed,
            source: s.source.rawValue,
            notes: nilIfEmpty(s.notes),
            created_at: ExportFormatting.iso(s.createdAt),
            updated_at: ExportFormatting.iso(s.updatedAt)
        )
    }

    private static func map(_ h: HealthWorkout) -> HealthWorkoutDTO {
        HealthWorkoutDTO(
            health_workout_id: h.id.uuidString,
            apple_health_uuid: h.appleHealthUUID,
            workout_type: h.workoutType,
            start_time: ExportFormatting.iso(h.startTime),
            end_time: ExportFormatting.iso(h.endTime),
            duration_seconds: h.durationSeconds,
            active_energy_kcal: h.activeEnergyKcal,
            total_energy_kcal: h.totalEnergyKcal,
            avg_heart_rate_bpm: h.avgHeartRateBpm,
            min_heart_rate_bpm: h.minHeartRateBpm,
            max_heart_rate_bpm: h.maxHeartRateBpm,
            heart_rate_sample_count: h.heartRateSampleCount,
            source_name: h.sourceName,
            source_device: h.sourceDevice,
            imported_at: ExportFormatting.iso(h.importedAt)
        )
    }

    private static func map(_ j: JournalEntry) -> JournalDTO {
        JournalDTO(
            entry_id: j.id.uuidString,
            workout_id: j.workout?.id.uuidString,
            exercise_id: j.exerciseIdOptional?.uuidString,
            set_id: j.setIdOptional?.uuidString,
            timestamp: ExportFormatting.iso(j.timestamp),
            entry_type: j.entryType.rawValue,
            text: j.text,
            created_at: ExportFormatting.iso(j.createdAt),
            updated_at: ExportFormatting.iso(j.updatedAt)
        )
    }

    private static func map(_ e: Exercise) -> ExerciseDTO {
        let aliases = (e.aliases ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .map { a in
                AliasDTO(
                    alias_id: a.id.uuidString,
                    alias_name: a.aliasName,
                    language: a.languageOptional,
                    created_at: ExportFormatting.iso(a.createdAt)
                )
            }
        return ExerciseDTO(
            exercise_id: e.id.uuidString,
            canonical_name: e.canonicalName,
            category: e.category?.rawValue,
            equipment: e.equipment?.rawValue,
            movement_pattern: e.movementPattern?.rawValue,
            default_weight_mode: e.defaultWeightMode.rawValue,
            primary_muscles: e.primaryMusclesRaw,
            secondary_muscles: e.secondaryMusclesRaw,
            aliases: aliases,
            notes: nilIfEmpty(e.notes),
            archived: e.archived,
            is_goal_exercise: e.isGoalExercise,
            is_favorite: e.isFavorite,
            created_at: ExportFormatting.iso(e.createdAt),
            updated_at: ExportFormatting.iso(e.updatedAt)
        )
    }

    private static func mapWorkout(_ w: WorkoutSession, request: ExportRequest, data: ExportDataSet) -> WorkoutDTO {
        let setsForWorkout = data.sets
            .filter { $0.workout?.id == w.id }
            .sorted {
                if $0.setIndex != $1.setIndex { return $0.setIndex < $1.setIndex }
                return $0.timestamp < $1.timestamp
            }
        let journalForWorkout: [JournalDTO]
        if request.includeJournal {
            journalForWorkout = data.journalEntries
                .filter { $0.workout?.id == w.id }
                .sorted { $0.timestamp < $1.timestamp }
                .map(map)
        } else {
            journalForWorkout = []
        }
        let linkedHealth: HealthWorkoutDTO?
        if request.includeHealthData, let hw = w.linkedHealthWorkout {
            linkedHealth = map(hw)
        } else {
            linkedHealth = nil
        }
        let metadata = SessionMetadataDTO(
            goal: w.goal?.rawValue,
            location: w.location?.rawValue,
            energy_before: w.energyBefore,
            soreness: w.soreness?.rawValue,
            pain_today: w.painToday?.rawValue,
            sleep_quality_subjective: w.sleepQualitySubjective?.rawValue,
            stress_level: w.stressLevel,
            food_timing: w.foodTiming?.rawValue,
            caffeine: w.caffeine?.rawValue,
            body_weight_manual_kg: w.bodyWeightManualKg,
            notes: nilIfEmpty(w.notes)
        )
        return WorkoutDTO(
            workout_id: w.id.uuidString,
            title: nilIfEmpty(w.title),
            start_time: ExportFormatting.iso(w.startTime),
            end_time: ExportFormatting.iso(w.endTime),
            timezone: w.timezoneIdentifier,
            duration_seconds: w.duration,
            is_backfilled: w.isBackfilled,
            session_metadata: metadata,
            sets: setsForWorkout.map(map),
            linked_health_workout: linkedHealth,
            journal_entries: journalForWorkout,
            created_at: ExportFormatting.iso(w.createdAt),
            updated_at: ExportFormatting.iso(w.updatedAt)
        )
    }

    // MARK: - Public builders

    static func makeDocument(_ data: ExportDataSet, request: ExportRequest) -> ExportDocument {
        ExportDocument(
            export_version: AppInfo.exportVersion,
            schema_version: AppInfo.exportSchemaVersion,
            exported_at: ExportFormatting.iso(data.generatedAt),
            app_version: "\(AppInfo.version)+\(AppInfo.build)",
            timezone: TimeZone.current.identifier,
            date_range_start: request.dateRangeStart.map { ExportFormatting.iso($0) },
            date_range_end: request.dateRangeEnd.map { ExportFormatting.iso($0) },
            units: Units(weight: ExportFormatting.weightUnit),
            workouts: data.workouts.map { mapWorkout($0, request: request, data: data) },
            exercises: data.exercises.map(map),
            body_weight_entries: request.includeBodyWeight ? data.bodyWeightEntries.map { b in
                BodyWeightDTO(
                    entry_id: b.id.uuidString,
                    timestamp: ExportFormatting.iso(b.timestamp),
                    weight_kg: b.weightKg,
                    source: b.source.rawValue,
                    apple_health_sample_id: b.appleHealthSampleId,
                    notes: nilIfEmpty(b.notes)
                )
            } : [],
            sleep_entries: request.includeSleep ? data.sleepEntries.map { s in
                SleepDTO(
                    entry_id: s.id.uuidString,
                    date: ExportFormatting.iso(s.date),
                    start_time: s.startTime.map { ExportFormatting.iso($0) },
                    end_time: s.endTime.map { ExportFormatting.iso($0) },
                    duration_seconds: s.durationSeconds,
                    source: s.source.rawValue,
                    subjective_sleep_quality: s.subjectiveSleepQuality?.rawValue,
                    apple_health_sample_id: s.appleHealthSampleId,
                    notes: nilIfEmpty(s.notes)
                )
            } : []
        )
    }

    /// Encode the export document to pretty-printed, key-sorted JSON `Data`.
    static func encode(_ data: ExportDataSet, request: ExportRequest) throws -> Data {
        let document = makeDocument(data, request: request)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(document)
    }
}
