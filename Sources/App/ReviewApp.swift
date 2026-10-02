import SwiftUI
import SpatialPreview
import RealityKit
import UniformTypeIdentifiers

@main struct SpatialProductReviewApp: App {
  @State private var model = ReviewModel()
  var body: some SwiftUI.Scene {
    Window("Spatial Product Review", id: "workspace") {
      ReviewWorkspace(model: model).frame(minWidth: 900, minHeight: 620)
    }.defaultSize(width: 980, height: 660)
  }
}

struct ReviewWorkspace: View {
  @Bindable var model: ReviewModel
  @State private var importing = false
  @State private var choosingDevice = false
  @State private var showArchive = false
  @State private var showInspector = true
  @State private var modelURL: URL?
  @State private var exporting = false
  @State private var exportDocument = ReviewDocument()
  var body: some View {
    NavigationSplitView {
      List(selection: $model.selectedID) {
        ForEach(model.reviews.filter { $0.archived == showArchive }) { review in
          NavigationLink(value: review.id) {
            VStack(alignment: .leading, spacing: 4) {
              Text(review.title).font(.headline)
              Text("\(review.notes.filter { !$0.resolved }.count) open notes").font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4).accessibilityIdentifier("review-" + review.id.uuidString)
          }
        }
      }
      .navigationTitle(showArchive ? "Archive" : "Products")
      .safeAreaInset(edge: .bottom) {
        Toggle("Show archive", isOn: $showArchive).toggleStyle(.switch).accessibilityIdentifier("showArchive").padding()
          .onChange(of: showArchive) { model.selectedID = nil }
      }
      .navigationSplitViewColumnWidth(min: 210, ideal: 240)
    } detail: {
      if let review = model.selected {
        GeometryReader { geometry in
          VStack(spacing: 0) {
            if let modelURL { ModelPreview(url: modelURL).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else { ProgressView("Loading model").frame(maxWidth: .infinity, maxHeight: .infinity) }
            HStack {
              Label("Local model copy", systemImage: "externaldrive")
              Spacer()
              Text("Drag to rotate · Scroll to zoom")
            }.font(.caption).foregroundStyle(.secondary).padding()
          }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .navigationTitle(review.title)
        .task(id: review.id) { modelURL = nil; modelURL = await model.store.modelURL(for: review.id) }
      } else {
        ContentUnavailableView {
          Label("Review in three dimensions", systemImage: "cube.transparent")
        } description: {
          Text("Import a USDZ model or try the original desk lamp. Keep review notes here, then present the model on Apple Vision Pro.")
        } actions: {
          Button("Add sample product", action: model.addSample).disabled(model.isBusy)
          Button("Import model") { importing = true }.disabled(model.isBusy)
        }
      }
    }
    .inspector(isPresented: $showInspector) {
      if let review = model.selected {
        ReviewInspector(review: review, model: model).inspectorColumnWidth(min: 260, ideal: 290, max: 360)
      } else {
        ContentUnavailableView("Select a product", systemImage: "cube")
          .inspectorColumnWidth(min: 260, ideal: 290, max: 360)
      }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Review details", systemImage: "sidebar.right") { showInspector.toggle() }
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Import model", systemImage: "square.and.arrow.down") { importing = true }
          .disabled(model.isBusy).keyboardShortcut("o")
      }
      ToolbarItem(placement: .primaryAction) {
        Button("Export review", systemImage: "square.and.arrow.up") {
          guard let selected = model.selected else { return }
          exportDocument = ReviewDocument(review: selected); exporting = true
        }.disabled(model.selected == nil)
      }
      ToolbarItem(placement: .primaryAction) {
        if model.session == nil {
          Button("Present on Vision Pro", systemImage: "vision.pro") { choosingDevice = true }
            .disabled(model.selected == nil || model.isBusy)
        } else {
          Button("End presentation", systemImage: "stop.circle") { Task { await model.disconnect() } }
        }
      }
    }
    .safeAreaInset(edge: .bottom) {
      if let session = model.session {
        HStack {
          Label(sessionLabel(session.state), systemImage: "vision.pro")
          if let name = model.reviews.first(where: { $0.id == model.sessionProductID })?.title { Text(name).foregroundStyle(.secondary) }
          Spacer()
          Text("End this presentation before choosing another model.").foregroundStyle(.secondary)
        }.font(.callout).padding()
      } else if model.isBusy {
        HStack { ProgressView().controlSize(.small); Text("Preparing model…"); Spacer(); Button("Cancel") { model.operation?.cancel() } }.padding()
      }
    }
    .sheet(isPresented: $choosingDevice) {
      SpatialPreviewDevicePicker(isPresented: $choosingDevice) { endpoint in choosingDevice = false; model.present(on: endpoint) }.frame(width: 520, height: 420)
    }
    .task { await model.load() }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.usdz]) { result in
      do { model.importModel(try result.get()) } catch { model.error = error.localizedDescription }
    }
    .fileExporter(isPresented: $exporting, document: exportDocument, contentType: .json, defaultFilename: "Product review") { result in
      if case .failure(let error) = result { model.error = error.localizedDescription }
    }
    .alert("Unable to complete request", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
      Button("OK") { model.error = nil }
    } message: { Text(model.error ?? "") }
    .onDisappear { model.operation?.cancel(); Task { await model.disconnect() } }
  }
  private func sessionLabel(_ state: SpatialPreviewSessionState) -> String {
    switch state {
    case .waiting: "Connecting…"
    case .connected: "Presenting on Vision Pro"
    case .interrupted: "Presentation interrupted"
    case .invalidated: "Presentation ended"
    @unknown default: "Presentation status unavailable"
    }
  }
}

struct ModelPreview: View {
  let url: URL
  @State private var failure: String?
  @State private var loaded = false
  var body: some View {
    RealityView { content in
      content.camera = .virtual
      do {
        let entity = try await Entity(contentsOf: url)
        try Task.checkCancellation()
        entity.orientation = simd_quatf(angle: .pi / 8, axis: [0, 1, 0])
        content.add(entity)
        content.cameraTarget = entity
        loaded = true
      } catch is CancellationError {} catch { failure = error.localizedDescription }
    }.realityViewCameraControls(.orbit)
      .overlay {
        if let failure { ContentUnavailableView("Model preview unavailable", systemImage: "cube", description: Text(failure)) }
        else if !loaded { ProgressView("Loading model") }
      }
      .accessibilityLabel(loaded ? "Interactive product model" : "Loading product model")
      .id(url)
  }
}

struct ReviewInspector: View {
  let review: ProductReview
  let model: ReviewModel
  @State private var title = ""
  @State private var note = ""
  @State private var saving = false
  var body: some View {
    Form {
      Section("Product") {
        TextField("Product name", text: $title).accessibilityIdentifier("productName")
        Button("Save name") { var changed = review; changed.title = title; save(changed) }
          .disabled(title == review.title || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200)
        LabeledContent("Imported", value: review.created.formatted(date: .abbreviated, time: .omitted))
      }
      Section("Review notes") {
        TextField("Add a review note", text: $note, axis: .vertical).lineLimit(3...6).accessibilityIdentifier("newNote")
        Button("Add note") {
          var changed = review; changed.notes.append(ReviewNote(text: note.trimmingCharacters(in: .whitespacesAndNewlines)))
          save(changed) { note = "" }
        }.disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || note.count > 2_000 || review.notes.count >= 100)
        if review.notes.isEmpty { Text("Capture questions about materials, dimensions, and finish.").foregroundStyle(.secondary) }
        ForEach(review.notes) { item in
          Toggle(isOn: Binding(get: { item.resolved }, set: { value in
            var changed = review
            if let index = changed.notes.firstIndex(where: { $0.id == item.id }) { changed.notes[index].resolved = value; save(changed) }
          })) { Text(item.text).strikethrough(item.resolved).foregroundStyle(item.resolved ? .secondary : .primary) }
            .toggleStyle(.checkbox).accessibilityLabel("Resolved: \(item.text)")
        }
      }
      Section {
        Button(review.archived ? "Restore product" : "Archive product") {
          var changed = review; changed.archived.toggle(); save(changed) { model.selectedID = nil }
        }
        Text("Archived products keep their models and notes.").font(.caption).foregroundStyle(.secondary)
      }
    }.formStyle(.grouped).disabled(saving)
      .onChange(of: review.id, initial: true) { title = review.title; note = "" }
  }
  private func save(_ changed: ProductReview, onSuccess: @escaping @MainActor () -> Void = {}) {
    saving = true
    Task { if await model.save(changed) { onSuccess() }; saving = false }
  }
}

struct ReviewDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data = Data()
  init() {}
  init(review: ProductReview) {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    data = (try? encoder.encode(review)) ?? Data()
  }
  init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
