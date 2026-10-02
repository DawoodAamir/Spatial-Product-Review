import Foundation
import Observation
import SpatialPreview

@MainActor @Observable final class ReviewModel {
  var reviews: [ProductReview] = []
  var selectedID: UUID?
  var error: String?
  var isBusy = false
  var session: DocumentPreviewSession?
  var sessionProductID: UUID?
  var operation: Task<Void, Never>?
  private var generation = UUID()
  let store: ReviewStore
  init() {
    var base = URL.applicationSupportDirectory.appendingPathComponent("SpatialProductReview", isDirectory: true)
    #if DEBUG
    if let testID = ProcessInfo.processInfo.environment["REVIEW_TEST_STORE"], UUID(uuidString: testID) != nil {
      base = base.appendingPathComponent("Tests/" + testID)
    }
    #endif
    store = ReviewStore(directory: base)
  }
  var selected: ProductReview? { reviews.first { $0.id == selectedID } }
  func load() async {
    do { reviews = try await store.list() } catch { self.error = error.localizedDescription }
  }
  func importModel(_ url: URL) {
    guard !isBusy else { return }
    isBusy = true
    operation = Task {
      defer { isBusy = false; operation = nil }
      do {
        let review = try await store.importModel(url)
        reviews.insert(review, at: 0); selectedID = review.id
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
  }
  func addSample() {
    guard !isBusy else { return }
    isBusy = true
    operation = Task {
      defer { isBusy = false; operation = nil }
      do {
        guard let url = Bundle.main.url(forResource: "Desk Lamp", withExtension: "usdz", subdirectory: "Samples") else { throw ReviewError.missingModel }
        var review = try await store.importModel(url); review.title = "Desk Lamp"; review = try await store.save(review)
        reviews.insert(review, at: 0); selectedID = review.id
      } catch is CancellationError {} catch { self.error = error.localizedDescription }
    }
  }
  func save(_ changed: ProductReview) async -> Bool {
    do {
      let saved = try await store.save(changed)
      if let index = reviews.firstIndex(where: { $0.id == saved.id }) { reviews[index] = saved }
      return true
    } catch { self.error = error.localizedDescription; return false }
  }
  func present(on endpoint: SpatialPreviewEndpoint) {
    guard let review = selected, !isBusy, session == nil else { return }
    let token = UUID(); generation = token; isBusy = true
    let preview = DocumentPreviewSession(name: review.title, contentType: .usdz)
    session = preview; sessionProductID = review.id
    operation = Task {
      defer { if generation == token { isBusy = false; operation = nil } }
      do {
        try await preview.start(endpoint: endpoint)
        try Task.checkCancellation()
        try await preview.updateContents(url: store.modelURL(for: review.id))
        try Task.checkCancellation()
      } catch {
        try? await preview.close()
        if generation == token { session = nil; sessionProductID = nil; if !(error is CancellationError) { self.error = error.localizedDescription } }
      }
    }
  }
  func disconnect() async {
    generation = UUID(); operation?.cancel(); operation = nil; isBusy = false
    guard let preview = session else { return }
    if preview.state.isInvalidated { session = nil; sessionProductID = nil; return }
    do { try await preview.close(); session = nil; sessionProductID = nil }
    catch { self.error = error.localizedDescription }
  }
}
