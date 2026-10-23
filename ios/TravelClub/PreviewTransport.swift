#if DEBUG
import Foundation
// Explicit simulator-only UI fixture. Normal launches always use the live server.
final class PreviewTransport: URLProtocol {
    static var read = false
    static var added = false
    static var notes: [[String:Any]] = []
    static let trip: [String:Any] = ["id":"demo-trip","title":"Бурея · проверка приложения","place":"Амурская область","body":"Проверка новых экранов. Эти данные существуют только в симуляторе.","author":"Автор","author_id":"demo-owner","created_at":1784000000,"version":1,"photos":["/api/photos/demo-photo"],"captions":["/api/photos/demo-photo":"Зеркальная вода"],"photoAuthors":["/api/photos/demo-photo":"demo-owner"]]
    static let stop: [String:Any] = ["title":"Зеркальная вода","note":"Тихий затон · Бурея","lat":50.587,"lon":131.429,"photoIds":["demo-photo"]]
    override class func canInit(with request:URLRequest)->Bool{true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
    override func stopLoading(){}
    override func startLoading(){
        let path=request.url!.path
        var value:[String:Any]=[:]
        switch path {
        case "/api/trips":value=["trips":[Self.trip]]
        case "/api/notifications":value=["notifications":[["id":"demo-notice","trip_id":"demo-trip","title":"Бурея · проверка приложения","inviter":"Друг","created_at":1784000000,"read_at":Self.read ? (1784000001 as Any) : (NSNull() as Any)]]]
        case "/api/notifications/read":Self.read=true
        case "/api/trips/demo-trip/route":value=["stops":[Self.stop],"transport":"На катере","budget":"","packing":"Дождевик","advice":"","version":1]
        case "/api/trips/demo-trip/team":if request.httpMethod == "POST"{Self.added.toggle()};value=["ownerId":"demo-owner","canContribute":true,"people":[["id":"demo-owner","name":"Автор","username":"owner"],["id":"demo-friend","name":"Друг","username":"friend"]],"memberIds":Self.added ? ["demo-friend"]:[]]
        case "/api/trips/demo-trip/notes":value=["notes":Self.notes]
        case "/api/trips/demo-trip/trip-invite":value=["token":String(repeating:"a",count:64)]
        case "/api/photos/demo-photo/details":value=["caption":"Зеркальная вода","author":"Автор","comments":[]]
        default:value=["comments":[]]
        }
        let data:Data
        if path == "/api/photos/demo-photo",let url=Bundle.main.url(forResource:"bureya-hero",withExtension:"jpg"),let photo=try? Data(contentsOf:url){data=photo}
        else{data=(try? JSONSerialization.data(withJSONObject:value)) ?? Data("{}".utf8)}
        client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
    }
}
#endif
