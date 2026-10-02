import Foundation
import Testing
@testable import SpatialReviewCore

@MainActor @Test func modelCopyNotesAndArchiveSurviveReload() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("Original.usdz")
  let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Samples/Desk Lamp.usdz")
  try FileManager.default.copyItem(at: fixture, to: source)
  let original = try Data(contentsOf: source)
  let store = ReviewStore(directory: root.appendingPathComponent("Library"))
  var review = try await store.importModel(source)
  let stale = review
  review.notes = [ReviewNote(text: "Check the enclosure finish.")]
  review = try await store.save(review)
  review.notes[0].resolved = true; review.archived = true
  review = try await store.save(review)
  let reopened = ReviewStore(directory: root.appendingPathComponent("Library"))
  #expect(try await reopened.list() == [review])
  #expect(try Data(contentsOf: await store.modelURL(for: review.id)) == original)
  #expect(try Data(contentsOf: source) == original)
  do { _ = try await store.save(stale); Issue.record("Stale changes were accepted") }
  catch ReviewError.staleRevision {} catch { throw error }
  review.archived = false
  _ = try await store.save(review)
  #expect(try await reopened.list().first?.archived == false)
}

@Test func invalidImportDoesNotCreateReview() async throws {
  let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: root) }
  let source = root.appendingPathComponent("invalid.txt")
  try Data("Not a model".utf8).write(to: source)
  let store = ReviewStore(directory: root.appendingPathComponent("Library"))
  do { _ = try await store.importModel(source); Issue.record("Invalid model accepted") }
  catch ReviewError.invalidModel {} catch { throw error }
  #expect(try await store.list().isEmpty)
}

@Test func boundedReviewValidation() throws {
  var review = ProductReview(title: "Lamp")
  review.notes = [ReviewNote(text: String(repeating: "x", count: 2_001))]
  #expect(throws: ReviewError.self) { try review.validate() }
  review.notes = []; review.title = "  "
  #expect(throws: ReviewError.self) { try review.validate() }
  review.title = "Lamp"; review.formatVersion = 2
  #expect(throws: ReviewError.self) { try review.validate() }
}
