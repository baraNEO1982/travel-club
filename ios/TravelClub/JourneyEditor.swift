import SwiftUI
import PhotosUI
import UIKit
import ImageIO

struct PendingPhoto: Identifiable { let id: String; let data: Data }
struct JourneyEditor: View {
    @ObservedObject var club: ClubModel
    let trip: Journey?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var place: String
    @State private var story: String
    @State private var selection: [PhotosPickerItem] = []
    @State private var photos: [PendingPhoto] = []
    @State private var busy = false
    @State private var preparing = false
    @State private var started = false
    @State private var savedStory = false
    @State private var uploaded: Set<String> = []
    @State private var error: String?
    @State private var progress = ""
    @State private var confirmClose = false
    @State private var tripID: String
    @State private var mutation = UUID().uuidString.lowercased()
    init(club: ClubModel, trip: Journey?) {
        self.club = club; self.trip = trip
        _title = State(initialValue: trip?.title ?? ""); _place = State(initialValue: trip?.place ?? "")
        _story = State(initialValue: trip?.body ?? ""); _tripID = State(initialValue: trip?.id ?? UUID().uuidString.lowercased())
    }
    private var valid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 140 && place.count <= 120 && !story.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && story.count <= 30000 }
    var body: some View {
        NavigationStack {
            Form {
                storyFields
                photoFields
                if started { Section { Text("Сохранение началось. При сбое повторите отправку: уже сохранённый рассказ и фото не будут продублированы.").font(.footnote) } }
                if let error { Section { Text(error).foregroundStyle(.red).textSelection(.enabled) } }
                if !progress.isEmpty { Text(progress) }
                Button(busy ? "Сохраняем…" : started ? "Повторить сохранение" : "Сохранить путешествие") { Task { await save() } }
                    .disabled(busy || preparing || !valid)
            }
            .navigationTitle(trip == nil ? "Новое путешествие" : "Дополнить рассказ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { confirmClose = true }.disabled(busy || preparing) } }
            .confirmationDialog("Закрыть редактор? Несохранённые изменения будут потеряны. Уже отправленные данные останутся в клубе.", isPresented: $confirmClose, titleVisibility: .visible) { Button("Закрыть", role: .destructive) { Task { if started { await club.refresh() }; dismiss() } } }
        }
        .interactiveDismissDisabled()
        .onChange(of: selection) { _, items in Task { await prepare(items) } }
    }
    private var storyFields: some View {
                Section("Рассказ") {
                    TextField("Название путешествия", text: $title)
                    TextField("Место", text: $place)
                    TextEditor(text: $story).frame(minHeight: 200).accessibilityLabel("Ваш рассказ")
                    Text("Название — до 140 символов, место — до 120, рассказ — до 30 000.").font(.caption).foregroundStyle(.secondary)
                }.disabled(busy || started)
    }
    private var photoFields: some View {
                Section("Фотографии") {
                    if let trip { Text("Уже сохранено: \(trip.photos.count). Существующие фото останутся.") }
                    if photos.count < 12 && photos.count + (trip?.photos.count ?? 0) < 100 {
                        PhotosPicker(selection: $selection, maxSelectionCount: min(12 - photos.count, 100 - (trip?.photos.count ?? 0) - photos.count), matching: .images) { Label("Добавить фотографии", systemImage: "photo.badge.plus") }.disabled(busy || started || preparing)
                    }
                    Text("До 12 новых фото за раз и до 100 в путешествии. Фото до 10 МБ уменьшаются перед отправкой.").font(.caption)
                    if preparing { ProgressView("Подготавливаем фотографии…") }
                    ForEach(photos) { photo in
                        HStack {
                            if let image = UIImage(data: photo.data) { Image(uiImage: image).resizable().scaledToFit().frame(width: 80, height: 70) }
                            Spacer()
                            if uploaded.contains(photo.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            else { Button("Убрать", role: .destructive) { photos.removeAll { $0.id == photo.id } }.disabled(busy || started) }
                        }
                    }
                }
    }
    private func prepare(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty, !preparing else { return }; preparing = true; error = nil; defer { preparing = false; selection = [] }
        do {
            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self), data.count <= 10 * 1024 * 1024 else { throw ClubError(message: "Выберите фото размером до 10 МБ.") }
                let compressed = try await Task.detached(priority: .userInitiated) { try compressPhoto(data) }.value
                guard photos.count < 12, photos.count + (trip?.photos.count ?? 0) < 100 else { throw ClubError(message: "Достигнут лимит фотографий.") }
                photos.append(PendingPhoto(id: UUID().uuidString.lowercased(), data: compressed))
            }
        } catch { self.error = error.localizedDescription }
    }
    private func save() async {
        guard !busy, valid else { return }; busy = true; started = true; error = nil; defer { busy = false }
        do {
            if !savedStory {
                progress = "Сохраняем рассказ…"
                var body: [String: Any] = ["title": title, "place": place, "body": story]
                if let trip { body["version"] = trip.version; body["mutation"] = mutation }
                else { body["id"] = tripID }
                let _: IDResponse = try await club.api(trip == nil ? "/trips" : "/trips/" + tripID + "/edit", body: body)
                savedStory = true
            }
            for photo in photos where !uploaded.contains(photo.id) {
                progress = "Загружаем фото \(uploaded.count + 1) из \(photos.count)…"
                _ = try await club.request("/trips/" + tripID + "/photos", jpeg: photo.data, photoID: photo.id)
                uploaded.insert(photo.id)
            }
            await club.refresh(); dismiss()
        } catch { self.error = error.localizedDescription; progress = "Сохранено фото: \(uploaded.count) из \(photos.count)." }
    }
}
func compressPhoto(_ data: Data) throws -> Data {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: 1600] as CFDictionary) else { throw ClubError(message: "Не удалось прочитать фотографию.") }
    var image = UIImage(cgImage: cg)
    for _ in 0..<5 {
        for quality in [0.85, 0.7, 0.55, 0.4] {
            if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= 1_000_000 { return jpeg }
        }
        let size = CGSize(width: image.size.width * 0.75, height: image.size.height * 0.75)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        image = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
    throw ClubError(message: "Не удалось уменьшить фото до 1 МБ. Выберите другой снимок.")
}
