import Foundation
struct RouteStop: Codable {
    var title: String; var note: String; var lat: Double?; var lon: Double?; var photoIds: [String]?
}
struct TripRoute: Codable {
    var stops: [RouteStop]; var transport: String; var budget: String; var packing: String; var advice: String; var version: Int
    func payload() throws -> [String: Any] {
        var value = try JSONSerialization.jsonObject(with: JSONEncoder().encode(self)) as! [String: Any]
        value["stops"] = stops.map { ["title": $0.title, "note": $0.note, "lat": $0.lat as Any? ?? NSNull(), "lon": $0.lon as Any? ?? NSNull(), "photoIds": $0.photoIds ?? []] as [String: Any] }
        return value
    }
}
struct TripPerson: Decodable, Identifiable { let id: String; let name: String; let username: String }
struct TripTeam: Decodable { let ownerId: String; let canContribute: Bool; let people: [TripPerson]; let memberIds: [String] }
struct TripNote: Decodable, Identifiable { let id: String; let body: String; let author: String; let author_id: String; let version: Int }
struct TripNotes: Decodable { let notes: [TripNote] }
struct TripJoined: Decodable { let tripId: String }
struct ClubNotice: Decodable, Identifiable { let id: String; let trip_id: String; let title: String; let inviter: String; let created_at: Double; let read_at: Double? }
struct ClubInbox: Decodable { let notifications: [ClubNotice] }
