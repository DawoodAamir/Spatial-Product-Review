import Foundation
import ModelIO

public struct ReviewNote: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public var text: String
  public var resolved: Bool
  public init(text: String) { id = UUID(); self.text = text; resolved = false }
}

public struct ProductReview: Codable, Identifiable, Equatable, Sendable {
  public let id: UUID
  public let created: Date
  public var title: String
  public var revision: Int
  public var notes: [ReviewNote]
  public var archived: Bool
  public var formatVersion: Int = 1
  public init(title: String) {
    id = UUID(); created = Date(); self.title = title; revision = 0; notes = []; archived = false
  }
  public func validate() throws {
    guard formatVersion == 1, revision >= 0, revision < Int.max, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      title.count <= 200, notes.count <= 100, Set(notes.map(\.id)).count == notes.count,
      notes.allSatisfy({ !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.text.count <= 2_000 })
    else { throw ReviewError.invalidReview }
  }
}

public enum ReviewError: LocalizedError, Sendable {
  case invalidModel, invalidReview, staleRevision, missingModel
  public var errorDescription: String? {
    switch self {
    case .invalidModel: "Choose a valid USDZ model smaller than 100 MB."
    case .invalidReview: "Use a title of 1–200 characters and at most 100 notes of 1–2,000 characters."
    case .staleRevision: "This review changed. Reload it before saving again."
    case .missingModel: "The saved model is missing. Import the original model again."
    }
  }
}

/// Owns private model copies and atomic, revision-checked review metadata.
public actor ReviewStore {
  public let directory: URL
  public init(directory: URL) { self.directory = directory }
  public func modelURL(for id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".usdz") }
  private func recordURL(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".json") }
  public func list() throws -> [ProductReview] {
    guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "json" }.map { try read($0) }.sorted { $0.created > $1.created }
  }
  private func read(_ url: URL) throws -> ProductReview {
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max) <= 1_000_000 else { throw ReviewError.invalidReview }
    let review = try JSONDecoder().decode(ProductReview.self, from: Data(contentsOf: url))
    try review.validate()
    guard url.lastPathComponent == review.id.uuidString + ".json" else { throw ReviewError.invalidReview }
    return review
  }
  public func importModel(_ source: URL) throws -> ProductReview {
    let accessed = source.startAccessingSecurityScopedResource()
    defer { if accessed { source.stopAccessingSecurityScopedResource() } }
    let info = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard source.pathExtension.lowercased() == "usdz", info.isRegularFile == true,
      let size = info.fileSize, size > 0, size <= 100_000_000 else { throw ReviewError.invalidModel }
    try Task.checkCancellation()
    let asset = MDLAsset(url: source)
    guard asset.count > 0 else { throw ReviewError.invalidModel }
    var review = ProductReview(title: String(source.deletingPathExtension().lastPathComponent.prefix(200)))
    if review.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { review.title = "Untitled product" }
    try review.validate()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = modelURL(for: review.id)
    do {
      try FileManager.default.copyItem(at: source, to: destination)
      try Task.checkCancellation()
      try JSONEncoder().encode(review).write(to: recordURL(review.id), options: .atomic)
      return review
    } catch {
      try? FileManager.default.removeItem(at: destination)
      throw error
    }
  }
  public func save(_ review: ProductReview) throws -> ProductReview {
    try review.validate()
    let old = try read(recordURL(review.id))
    guard old.revision == review.revision else { throw ReviewError.staleRevision }
    guard FileManager.default.fileExists(atPath: modelURL(for: review.id).path) else { throw ReviewError.missingModel }
    var updated = review; updated.revision += 1
    try JSONEncoder().encode(updated).write(to: recordURL(review.id), options: .atomic)
    return updated
  }
}
