import SwiftUI
import MapKit

struct JourneyRouteView: View {
    @ObservedObject var club: ClubModel
    let trip: Journey
    @State private var route: TripRoute?
    @State private var error: String?
    @State private var editing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Маршрут и советы").font(.title2.bold())
            if let route {
                if !route.stops.isEmpty { JourneyMap(club: club, stops: route.stops) }
                if route.stops.isEmpty { Text("Автор пока не добавил остановки.").foregroundStyle(.secondary) }
                tip("Как добраться", route.transport); tip("Расходы и даты", route.budget)
                tip("Что взять с собой", route.packing); tip("Советы", route.advice)
                if trip.author_id == club.member?.id { Button("Дополнить маршрут") { editing = true }.buttonStyle(.bordered) }
            }
            if let error { Text(error).foregroundStyle(.red); Button("Повторить") { Task { await load() } } }
        }.task { await load() }
        .sheet(isPresented: $editing, onDismiss: { Task { await load() } }) {
            if let route { RouteEditor(club: club, tripID: trip.id, initial: route) }
        }
    }
    @ViewBuilder private func tip(_ title: String, _ value: String) -> some View {
        if !value.isEmpty { VStack(alignment: .leading) { Text(title).font(.headline); Text(value).textSelection(.enabled) } }
    }
    private func load() async { do { route = try await club.api("/trips/\(trip.id)/route"); error = nil } catch { self.error = error.localizedDescription } }
}
struct MapPhotoSelection: Identifiable { let id = UUID(); let stop: RouteStop; let index: Int }
struct JourneyMap: View {
    @ObservedObject var club: ClubModel
    let stops: [RouteStop]
    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: Int?
    @State private var photo: MapPhotoSelection?
    private var positions: [CLLocationCoordinate2D] { stops.compactMap { s in guard let lat = s.lat, let lon = s.lon else { return nil }; return CLLocationCoordinate2D(latitude: lat, longitude: lon) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Map(position: $camera) {
                ForEach(Array(stops.enumerated()), id: \.offset) { index, stop in
                    if let lat = stop.lat, let lon = stop.lon {
                        Annotation(stop.title, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            Button { selected = index } label: { Text("\(index+1)").font(.caption.bold()).padding(9).background(selected == index ? Color.orange : clubNavy, in: Circle()).foregroundStyle(.white) }.accessibilityLabel(stop.title)
                        }
                    }
                }
                MapPolyline(coordinates: positions).stroke(clubNavy.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [5,5]))
            }.frame(height: 320).clipShape(RoundedRectangle(cornerRadius: 14))
            Button("Весь маршрут") { camera = .automatic }
            Text("Пунктир — порядок остановок, не дорога.").font(.caption).foregroundStyle(.secondary)
            Picker("Остановка", selection: $selected) {
                Text("Выберите точку").tag(nil as Int?)
                ForEach(Array(stops.enumerated()), id: \.offset) { i, s in Text("\(i+1). \(s.title)").tag(i as Int?) }
            }.pickerStyle(.menu)
            if let selected, stops.indices.contains(selected) {
                let stop = stops[selected]
                Text(stop.title).font(.headline); Text(stop.note)
                ScrollView(.horizontal) {
                    HStack { ForEach(Array((stop.photoIds ?? []).enumerated()), id: \.element) { index, id in
                        Button { photo = MapPhotoSelection(stop: stop, index: index) } label: { PrivatePhoto(club: club, path: "/api/photos/"+id).frame(width: 130, height: 100).clipped() }.accessibilityLabel("Открыть фото \(index+1)")
                    } }
                }
            }
        }.onChange(of: selected) { _, index in
            if let index, let lat = stops[index].lat, let lon = stops[index].lon { camera = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))) }
        }.sheet(item: $photo) { selection in RoutePhotoViewer(club: club, selection: selection) }
    }
}
struct RoutePhotoViewer: View {
    @ObservedObject var club: ClubModel
    let selection: MapPhotoSelection
    @State private var index: Int
    init(club: ClubModel, selection: MapPhotoSelection) { self.club = club; self.selection = selection; _index = State(initialValue: selection.index) }
    var body: some View {
        VStack(spacing: 16) {
            Text(selection.stop.note).padding(.horizontal)
            TabView(selection: $index) { ForEach(Array((selection.stop.photoIds ?? []).enumerated()), id: \.element) { i, id in
                ScrollView { PrivatePhoto(club: club, path: "/api/photos/"+id).id(id) }.tag(i)
            } }.tabViewStyle(.page)
            Text("\(index+1) / \(selection.stop.photoIds?.count ?? 0)").padding()
        }.modifier(SheetHeader(title: selection.stop.title))
    }
}
struct RouteEditor: View {
    @ObservedObject var club: ClubModel
    let tripID: String
    @Environment(\.dismiss) private var dismiss
    @State private var route: TripRoute
    @State private var busy = false
    @State private var error: String?
    @State private var close = false
    init(club: ClubModel, tripID: String, initial: TripRoute) { self.club = club; self.tripID = tripID; _route = State(initialValue: initial) }
    var body: some View {
        NavigationStack {
            Form {
                Section("Остановки · до 30") {
                    ForEach(route.stops.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Остановка \(i+1)").font(.headline)
                            TextField("Название места", text: $route.stops[i].title)
                            TextField("Описание", text: $route.stops[i].note, axis: .vertical)
                            TextField("Широта", value: $route.stops[i].lat, format: .number).keyboardType(.numbersAndPunctuation)
                            TextField("Долгота", value: $route.stops[i].lon, format: .number).keyboardType(.numbersAndPunctuation)
                            HStack {
                                Button("Выше") { route.stops.swapAt(i,i-1) }.disabled(i==0)
                                Button("Ниже") { route.stops.swapAt(i,i+1) }.disabled(i==route.stops.count-1)
                                Spacer(); Button("Убрать", role: .destructive) { route.stops.remove(at:i) }
                            }.buttonStyle(.borderless)
                        }
                    }
                    Button("Добавить остановку") { route.stops.append(RouteStop(title:"",note:"",lat:nil,lon:nil,photoIds:[])) }.disabled(route.stops.count>=30)
                }
                Section("Практические детали") {
                    TextField("Как добраться", text:$route.transport,axis:.vertical)
                    TextField("Расходы и даты", text:$route.budget,axis:.vertical)
                    TextField("Что взять", text:$route.packing,axis:.vertical)
                    TextField("Советы", text:$route.advice,axis:.vertical)
                }
                if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                Button(busy ? "Сохраняем…":"Сохранить маршрут") { Task { busy=true;defer{busy=false};do { let _:TripRoute = try await club.api("/trips/\(tripID)/route",body:try route.payload());dismiss() } catch { self.error=error.localizedDescription } } }
            }.disabled(busy).navigationTitle("Маршрут").toolbar { Button("Закрыть") { close=true }.disabled(busy) }
            .confirmationDialog("Закрыть без сохранения?",isPresented:$close) { Button("Закрыть",role:.destructive){dismiss()} }
        }.interactiveDismissDisabled()
    }
}
