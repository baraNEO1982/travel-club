import SwiftUI
import UIKit

struct PrivatePhoto: View {
    @ObservedObject var club: ClubModel
    let path: String
    @State private var image: UIImage?
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        VStack {
            if let image { Image(uiImage: image).resizable().scaledToFit().accessibilityLabel("Фотография путешествия") }
            else if let error { Text(error).font(.footnote); Button("Загрузить фото ещё раз") { Task { await load() } }.disabled(busy) }
            else { ProgressView("Загружаем фото…").frame(maxWidth: .infinity, minHeight: 120) }
        }.task(id: path) { await load() }
    }
    private func load() async {
        guard image == nil, !busy, path.hasPrefix("/api/photos/") else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            let data = try await club.request(String(path.dropFirst(4)))
            guard let decoded = UIImage(data: data) else { throw ClubError(message: "Не удалось прочитать фото.") }
            image = decoded
        } catch is CancellationError { } catch { self.error = error.localizedDescription }
    }
}

struct JourneyView: View {
    @ObservedObject var club: ClubModel
    let original: Journey
    @State private var editing = false
    private var trip: Journey { club.journeys.first(where: { $0.id == original.id }) ?? original }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text(trip.title).font(.largeTitle.bold())
                Label(trip.place.isEmpty ? "Путешествие" : trip.place, systemImage: "mappin.and.ellipse")
                Text(trip.author + " · " + Date(timeIntervalSince1970: trip.created_at).formatted(date: .abbreviated, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
                if trip.author_id == club.member?.id { Button("Дополнить путешествие", systemImage: "square.and.pencil") { editing = true }.buttonStyle(.bordered) }
                Text(trip.body).textSelection(.enabled)
                ForEach(trip.photos, id: \.self) { path in
                    PhotoDiscussion(club: club, path: path, initialCaption: trip.captions[path] ?? "", canEdit: trip.author_id == club.member?.id)
                }
                Divider()
                CommentsView(club: club, path: "/trips/" + trip.id + "/comments", title: "Обсудим путешествие")
            }.padding(20)
        }.navigationTitle("История").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) { JourneyEditor(club: club, trip: trip) }
    }
}
struct CommentRows: View {
    let comments: [ClubComment]
    var body: some View {
        ForEach(comments) { comment in
            VStack(alignment: .leading, spacing: 5) {
                Text(comment.author).font(.headline)
                Text(comment.body).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
        }
    }
}
struct CommentsView: View {
    @ObservedObject var club: ClubModel
    let path: String
    let title: String
    @State private var comments: [ClubComment] = []
    @State private var text = ""
    @State private var loaded = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            if loaded && comments.isEmpty { Text("Пока нет комментариев.").foregroundStyle(.secondary) }
            CommentRows(comments: comments)
            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            if !loaded { Button("Загрузить обсуждение") { Task { await load() } }.disabled(busy) }
            TextField("Ваш комментарий", text: $text, axis: .vertical).lineLimit(3...8).textFieldStyle(.roundedBorder).disabled(busy)
            Text("\(text.count) / 4000").font(.caption).foregroundStyle(.secondary)
            Button(busy ? "Подождите…" : "Добавить комментарий") { Task { await send() } }
                .buttonStyle(.borderedProminent).disabled(busy || !loaded || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 4000)
            if loaded { Button("Обновить комментарии") { Task { await load() } }.disabled(busy) }
        }.task { if !loaded { await load() } }
    }
    private func load() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { let result: CommentsResponse = try await club.api(path); comments = result.comments; loaded = true }
        catch { self.error = error.localizedDescription }
    }
    private func send() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { let result: ClubComment = try await club.api(path, body: ["body": text]); comments.append(result); text = "" }
        catch { self.error = error.localizedDescription }
    }
}
struct PhotoDiscussion: View {
    @ObservedObject var club: ClubModel
    let path: String
    let initialCaption: String
    let canEdit: Bool
    @State private var caption = ""
    @State private var draft = ""
    @State private var comments: [ClubComment] = []
    @State private var text = ""
    @State private var loaded = false
    @State private var busy = false
    @State private var error: String?
    @State private var notice: String?
    private var endpoint: String { String(path.dropFirst(4)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PrivatePhoto(club: club, path: path)
            if !(loaded ? caption : initialCaption).isEmpty { Text(loaded ? caption : initialCaption).font(.body.italic()) }
            if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            if let notice { Text(notice).foregroundStyle(.secondary).font(.footnote) }
            if canEdit && loaded {
                TextField("Описание фотографии", text: $draft, axis: .vertical).lineLimit(2...6).textFieldStyle(.roundedBorder).disabled(busy)
                Button("Сохранить описание") { Task { await saveCaption() } }.disabled(busy || draft == caption || draft.count > 2000)
            }
            Text("Комментарии к фото").font(.headline)
            if loaded && comments.isEmpty { Text("Пока нет комментариев.").font(.subheadline).foregroundStyle(.secondary) }
            CommentRows(comments: comments)
            TextField("Комментарий к этому фото", text: $text, axis: .vertical).lineLimit(2...6).textFieldStyle(.roundedBorder).disabled(busy)
            Button(busy ? "Подождите…" : "Добавить комментарий") { Task { await send() } }.buttonStyle(.borderedProminent)
                .disabled(busy || !loaded || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 4000)
            Button(loaded ? "Обновить обсуждение" : "Загрузить обсуждение") { Task { await load() } }.disabled(busy)
        }.padding(14).background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .task { if !loaded { await load() } }
    }
    private func load() async {
        guard !busy else { return }; busy = true; error = nil; defer { busy = false }
        do { let result: PhotoDetails = try await club.api(endpoint + "/details"); caption = result.caption; draft = result.caption; comments = result.comments; loaded = true }
        catch { self.error = error.localizedDescription }
    }
    private func saveCaption() async {
        guard !busy else { return }; busy = true; error = nil; notice = nil; defer { busy = false }
        do { let result: CaptionResponse = try await club.api(endpoint + "/caption", body: ["caption": draft]); caption = result.caption; draft = result.caption; notice = "Описание сохранено." }
        catch { self.error = error.localizedDescription }
    }
    private func send() async {
        guard !busy else { return }; busy = true; error = nil; notice = nil; defer { busy = false }
        do { let result: ClubComment = try await club.api(endpoint + "/comments", body: ["body": text]); comments.append(result); text = "" }
        catch { self.error = error.localizedDescription }
    }
}
