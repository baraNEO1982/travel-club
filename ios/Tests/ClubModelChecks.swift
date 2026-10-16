import Foundation

final class Mock: URLProtocol {
    static var tripsFail = false
    static var log: [URLRequest] = []
    static var configuration: URLSessionConfiguration { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [Mock.self]; return c }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        Self.log.append(request)
        let path = request.url!.path
        if path == "/api/trips" && Self.tripsFail { client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return }
        var json = "{}"
        var status = 200
        switch path {
        case "/api/login", "/api/register": json = #"{"user":{"id":"u1","name":"Tester"}}"#
        case "/api/trips": json = #"{"trips":[{"id":"t1","author_id":"u1","title":"Trip","place":"Sea","body":"Story","author":"Tester","created_at":1234,"version":2,"photos":["/api/photos/p1"],"captions":{"/api/photos/p1":"Sunrise"}}]}"#
        case "/api/photos/p1/details": json = #"{"caption":"Sunrise","comments":[{"id":"c1","body":"Nice","author":"Other"}]}"#
        case "/api/photos/p1/comments", "/api/trips/t1/comments":
            json = request.httpMethod == "POST" ? #"{"id":"c2","body":"Hello","author":"Tester"}"# : #"{"comments":[{"id":"c1","body":"Nice","author":"Other"}]}"#
        case "/api/photos/p1/caption": json = #"{"caption":"Updated"}"#
        case "/api/invites": json = "{\"token\":\"" + String(repeating: "a", count: 64) + "\"}"
        case "/api/recovery/status", "/api/account/email": json = #"{"enabled":false,"email":null}"#
        case "/api/password/request": status = 503; json = #"{"error":"Отправка писем ещё не подключена."}"#
        case "/api/trips/t1/photos": json = #"{"id":"p2"}"#
        case "/api/trips/t1/edit": status = 409; json = #"{"error":"Рассказ уже изменён."}"#
        default: break
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
}
@main struct Checks {
    @MainActor static func main() async throws {
        let model = ClubModel(session: URLSession(configuration: Mock.configuration))
        await model.authenticate(username: "test", password: "test password")
        precondition(model.member != nil && model.journeysLoaded && model.journeys.count == 1)
        precondition(model.journeys[0].photos == ["/api/photos/p1"] && model.journeys[0].version == 2)
        let details: PhotoDetails = try await model.api("/photos/p1/details")
        precondition(details.caption == "Sunrise" && details.comments.count == 1)
        let comment: ClubComment = try await model.api("/photos/p1/comments", body: ["body":"Hello"])
        precondition(comment.body == "Hello")
        let _: ClubComment = try await model.api("/trips/t1/comments", body: ["body":"Hello"])
        let caption: CaptionResponse = try await model.api("/photos/p1/caption", body: ["caption":"Updated"])
        precondition(caption.caption == "Updated")
        let invite: InviteResponse = try await model.api("/invites", body: [:])
        precondition(clubToken(ClubModel.origin + "/#invite=" + invite.token, key: "invite") == invite.token)
        precondition(clubToken("https://evil.example/#invite=" + invite.token, key: "invite") == nil)
        precondition(clubToken(ClubModel.origin + "/#reset-password=" + invite.token, key: "invite") == nil)
        let email: EmailStatus = try await model.api("/account/email"); precondition(!email.enabled)
        do { let _: MessageResponse = try await model.api("/password/request", body:["email":"x@example.com"]); fatalError("Expected mail unavailable") } catch { precondition(error.localizedDescription.contains("не подключена")) }
        do { let _: IDResponse = try await model.api("/trips/t1/edit", body:["version":1,"mutation":"fixed"]); fatalError("Expected conflict") } catch { precondition(error.localizedDescription.contains("изменён")) }
        _ = try await model.request("/trips/t1/photos", jpeg: Data([255,216,255,217]), photoID:"stable-id")
        let upload = Mock.log.last!; precondition(upload.value(forHTTPHeaderField:"X-Photo-Id") == "stable-id" && upload.value(forHTTPHeaderField:"Content-Type") == "image/jpeg")
        for request in Mock.log where request.httpMethod == "POST" { precondition(request.value(forHTTPHeaderField:"Origin") == ClubModel.origin) }
        Mock.tripsFail = true; await model.refresh(); precondition(model.journeys.count == 1 && model.journeysError != nil)
        Mock.tripsFail = false; await model.refresh(); precondition(model.journeysError == nil)
        await model.logout(); precondition(model.member == nil && model.journeys.isEmpty)
        print("PASS: trips/photos decoding, comments, captions, invitation links, disabled email, edit conflict, upload IDs/Origin, failed refresh preservation, logout")
    }
}
