import XCTest
import SwiftData
import SwiftCheck
@testable import OpenCount

// Feature: open-count-ios, Property 10: Session search returns only matching sessions
// Validates: Requirements 1.6

// MARK: - Helpers

/// Builds an in-memory `ModelContainer` for isolated test use.
private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([
        CountSession.self,
        ObjectType.self,
        CountMarker.self,
        CountRegion.self,
        SessionImage.self,
        VideoFrameCount.self,
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [config])
}

/// A `StorageServiceProtocol` implementation backed by an in-memory SwiftData context.
/// Used to drive `SessionListViewModel` in tests without touching the real store.
@MainActor
private final class InMemoryStorageService: StorageServiceProtocol {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ session: CountSession) async throws {
        context.insert(session)
        try context.save()
    }

    func delete(_ session: CountSession) async throws {
        context.delete(session)
        try context.save()
    }

    func fetchAllSessions() async throws -> [CountSession] {
        let descriptor = FetchDescriptor<CountSession>(
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchSessions(matching query: String) async throws -> [CountSession] {
        guard !query.isEmpty else { return try await fetchAllSessions() }
        let descriptor = FetchDescriptor<CountSession>(
            predicate: #Predicate { $0.name.localizedStandardContains(query) },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}

// MARK: - Generators

/// Generates a non-empty ASCII-printable string suitable for session names.
/// Restricts to printable ASCII (0x20–0x7E) to avoid control characters that
/// could confuse `localizedCaseInsensitiveContains`.
private let sessionNameGen: Gen<String> = Gen<Int>.choose((1, 20)).flatMap { length in
    Gen<[Character]>.sequence(
        Array(repeating: Gen<Character>.fromElements(of: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 _-")), count: length)
    ).map { String($0) }
}.suchThat { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

/// Generates a non-empty search query from the same character set.
private let queryGen: Gen<String> = Gen<Int>.choose((1, 8)).flatMap { length in
    Gen<[Character]>.sequence(
        Array(repeating: Gen<Character>.fromElements(of: Array("abcdefghijklmnopqrstuvwxyz")), count: length)
    ).map { String($0) }
}

// MARK: - Tests

final class SessionSearchTests: XCTestCase {

    // MARK: Property 10: Session search returns only matching sessions
    //
    // For any list of CountSessions and any non-empty search query, the filtered
    // result SHALL contain only sessions whose name contains the query string
    // (case-insensitive), and SHALL contain all such sessions.
    //
    // Validates: Requirements 1.6

    func testSearchReturnsOnlyMatchingSessions() {
        // SwiftCheck property: for any random list of session names and any non-empty
        // query, filteredSessions == sessions whose name contains the query (case-insensitive).
        property("Search returns exactly the sessions whose names contain the query (case-insensitive)") <- forAll(
            Gen<Int>.choose((0, 10)).flatMap { count in
                Gen<[String]>.sequence(Array(repeating: sessionNameGen, count: count))
            },
            queryGen
        ) { (names: [String], query: String) in
            let semaphore = DispatchSemaphore(value: 0)
            var result = false

            Task { @MainActor in
                defer { semaphore.signal() }
                result = await Self.searchPropertyHolds(names: names, query: query)
            }

            semaphore.wait()
            return result
        }
    }

    // MARK: - Core property helper

    @MainActor
    private static func searchPropertyHolds(names: [String], query: String) async -> Bool {
        do {
            let container = try makeInMemoryContainer()
            let context = ModelContext(container)
            let storage = InMemoryStorageService(context: context)
            let viewModel = SessionListViewModel(storage: storage)

            // Insert sessions with staggered modifiedAt so ordering is deterministic.
            var insertedSessions: [CountSession] = []
            for (index, name) in names.enumerated() {
                let session = CountSession(
                    name: name,
                    modifiedAt: Date(timeIntervalSinceReferenceDate: Double(index))
                )
                try await storage.save(session)
                insertedSessions.append(session)
            }

            // Load sessions into the view model.
            await viewModel.loadSessions()

            // Apply the search query directly (bypasses the 300 ms debounce for test speed).
            viewModel.applyFilterForTesting(query: query)

            // Compute the expected set using `localizedStandardContains` — the same
            // algorithm used by `SessionListViewModel.applyFilter` (Requirement 30.7).
            let expectedNames = Set(
                names.filter { $0.localizedStandardContains(query) }
            )
            let actualNames = Set(viewModel.filteredSessions.map(\.name))

            // Property: filteredSessions contains exactly the matching sessions.
            return actualNames == expectedNames
        } catch {
            return false
        }
    }

    // MARK: - Unit tests

    /// Empty query returns all sessions.
    func testEmptyQueryReturnsAllSessions() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["Alpha", "Beta", "Gamma"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(Set(filteredNames), Set(names))
    }

    /// Query that matches no sessions returns an empty list.
    func testQueryWithNoMatchesReturnsEmpty() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["Apple", "Banana", "Cherry"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "zzz") }

        let count = await MainActor.run { viewModel.filteredSessions.count }
        XCTAssertEqual(count, 0)
    }

    /// Search is case-insensitive: "apple" matches "Apple".
    func testSearchIsCaseInsensitive() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let session = CountSession(name: "Apple Orchard")
        try await storage.save(session)

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "apple") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(filteredNames, ["Apple Orchard"])
    }

    /// Query that matches a subset returns only that subset.
    func testQueryMatchesSubset() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["Bird Count", "Car Survey", "Bird Watching", "Tree Count"]
        for (index, name) in names.enumerated() {
            let session = CountSession(
                name: name,
                modifiedAt: Date(timeIntervalSinceReferenceDate: Double(index))
            )
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "bird") }

        let filteredNames = await MainActor.run { Set(viewModel.filteredSessions.map(\.name)) }
        XCTAssertEqual(filteredNames, ["Bird Count", "Bird Watching"])
    }

    /// No sessions in store → filtered result is empty regardless of query.
    func testEmptyStoreAlwaysReturnsEmpty() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "anything") }

        let count = await MainActor.run { viewModel.filteredSessions.count }
        XCTAssertEqual(count, 0)
    }

    // MARK: - Unicode-aware search tests (Requirement 30.7)

    /// Vietnamese diacritics: searching "Hà Nội" matches the session with that name.
    func testVietnameseDiacriticsSearch() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["Hà Nội Survey", "Ho Chi Minh Count", "Bird Count"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "Hà Nội") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(filteredNames, ["Hà Nội Survey"])
    }

    /// CJK characters: searching "鸟" (bird in Chinese) matches the session.
    func testCJKCharacterSearch() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["鸟类调查", "车辆统计", "Bird Count"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "鸟") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(filteredNames, ["鸟类调查"])
    }

    /// Japanese katakana: searching "カウント" matches the session.
    func testJapaneseKatakanaSearch() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["カウントセッション", "鳥の調査", "Bird Count"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "カウント") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(filteredNames, ["カウントセッション"])
    }

    /// Korean: searching "조류" matches the session with that substring.
    func testKoreanSearch() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["조류 조사", "차량 계수", "Bird Count"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "조류") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(filteredNames, ["조류 조사"])
    }

    /// Arabic RTL text: searching "طيور" matches the session.
    func testArabicRTLSearch() async throws {
        let container = try makeInMemoryContainer()
        let context = await MainActor.run { ModelContext(container) }
        let storage = await MainActor.run { InMemoryStorageService(context: context) }
        let viewModel = await MainActor.run { SessionListViewModel(storage: storage) }

        let names = ["مسح الطيور", "إحصاء السيارات", "Bird Count"]
        for name in names {
            let session = CountSession(name: name)
            try await storage.save(session)
        }

        await viewModel.loadSessions()
        await MainActor.run { viewModel.applyFilterForTesting(query: "طيور") }

        let filteredNames = await MainActor.run { viewModel.filteredSessions.map(\.name) }
        XCTAssertEqual(filteredNames, ["مسح الطيور"])
    }
}
