import Foundation
import Combine

struct Member: Decodable { let id: String; let name: String }
struct MemberResponse: Decodable { let user: Member? }
struct Journey: Decodable, Identifiable {
    let id: String
    let title: String
    let place: String
    let body: String
    let author: String
    let author_id: String
    let created_at: Double
    let version: Int
    let photos: [String]
    let captions: [String: String]
}
struct JourneysResponse: Decodable { let trips: [Journey] }
struct ClubComment: Decodable, Identifiable { let id: String; let body: String; let author: String }
struct CommentsResponse: Decodable { let comments: [ClubComment] }
struct PhotoDetails: Decodable { let caption: String; let comments: [ClubComment] }
struct MessageResponse: Decodable { let message: String }
struct EmailStatus: Decodable { let enabled: Bool; let email: String? }
struct InviteResponse: Decodable { let token: String }
struct IDResponse: Decodable { let id: String }
struct CaptionResponse: Decodable { let caption: String }
struct ServerError: Decodable { let error: String }
struct ClubError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class ClubModel: ObservableObject {
    static let origin = "https://travel-club.baraneo-family-club.workers.dev"
    @Published var member: Member?
    @Published var journeys: [Journey] = []
    @Published var loadingJourneys = false
    @Published var journeysLoaded = false
    @Published var journeysError: String?
    @Published var busy = false
    @Published var error: String?
    // One private session for JSON and photos. No password or photo cache on disk.
    private let session: URLSession
    init(session: URLSession = URLSession(configuration: .ephemeral)) { self.session = session }

    func request(_ path: String, body: [String: Any]? = nil, jpeg: Data? = nil, photoID: String? = nil) async throws -> Data {
        guard path.hasPrefix("/"), let url = URL(string: Self.origin + "/api" + path) else {
            throw ClubError(message: "Не удалось открыть адрес клуба.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = jpeg == nil ? 30 : 90
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if body != nil || jpeg != nil {
            request.httpMethod = "POST"
            request.setValue(Self.origin, forHTTPHeaderField: "Origin")
            request.setValue(jpeg == nil ? "application/json" : "image/jpeg", forHTTPHeaderField: "Content-Type")
            request.httpBody = try jpeg ?? JSONSerialization.data(withJSONObject: body ?? [:])
            if let photoID { request.setValue(photoID, forHTTPHeaderField: "X-Photo-Id") }
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError {
            // Discard broken connections after a network/VPN change. Never replay a POST.
            await session.flush()
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw ClubError(message: "Сервер не ответил вовремя. Попробуйте ещё раз.")
            case .cannotFindHost, .dnsLookupFailed: throw ClubError(message: "Не удалось найти адрес сервера. Проверьте соединение с интернетом и настройки VPN.")
            default: throw ClubError(message: "Не удалось связаться с клубом. Проверьте интернет и повторите попытку.")
            }
        }
        guard let response = response as? HTTPURLResponse else { throw ClubError(message: "Сервер не ответил.") }
        guard (200..<300).contains(response.statusCode) else {
            throw ClubError(message: (try? JSONDecoder().decode(ServerError.self, from: data).error) ?? "Не удалось выполнить действие.")
        }
        return data
    }
    func api<T: Decodable>(_ path: String, body: [String: Any]? = nil) async throws -> T {
        let data = try await request(path, body: body)
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw ClubError(message: "Не удалось прочитать ответ сервера. Повторите попытку.") }
    }
    func authenticate(username: String, password: String, name: String? = nil, invite: String? = nil) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        var body: [String: Any] = ["username": username.trimmingCharacters(in: .whitespacesAndNewlines), "password": password]
        if let name, let invite { body["name"] = name; body["invite"] = invite }
        do {
            // Login has no authenticated work in flight. Reset stale transport discovery
            // and cookies from previous attempts before establishing a new session.
            if member == nil { await session.reset() }
            let result: MemberResponse = try await api(invite == nil ? "/login" : "/register", body: body)
            guard let user = result.user else { throw ClubError(message: "Войдите в клуб ещё раз.") }
            member = user
            await refresh()
        } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
        guard member != nil, !loadingJourneys else { return }
        loadingJourneys = true; journeysError = nil
        defer { loadingJourneys = false }
        do { let result: JourneysResponse = try await api("/trips"); journeys = result.trips; journeysLoaded = true }
        catch { journeysError = error.localizedDescription }
    }
    func clearSession() {
        for cookie in session.configuration.httpCookieStorage?.cookies ?? [] { session.configuration.httpCookieStorage?.deleteCookie(cookie) }
        member = nil; journeys = []; journeysLoaded = false; journeysError = nil; error = nil
    }
    func logout() async {
        guard !busy, !loadingJourneys else { return }
        busy = true; error = nil
        defer { busy = false }
        do { _ = try await request("/logout", body: [:]); clearSession() }
        catch { self.error = error.localizedDescription }
    }
}

// Accept a pasted website link or a raw one-use token, never arbitrary hosts.
func clubToken(_ value: String, key: String) -> String? {
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let candidate: String
    if text.count == 64 { candidate = text }
    else if let url = URLComponents(string: text), url.scheme == "https", url.host == "travel-club.baraneo-family-club.workers.dev", let fragment = url.fragment,
            let token = URLComponents(string: "?" + fragment)?.queryItems?.first(where: { $0.name == key })?.value { candidate = token }
    else { return nil }
    return candidate.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil ? candidate : nil
}
