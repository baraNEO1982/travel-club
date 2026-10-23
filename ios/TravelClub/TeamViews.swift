import SwiftUI

struct JourneyTeamView: View {
    @ObservedObject var club: ClubModel
    let trip: Journey
    @State private var team: TripTeam?
    @State private var notes: [TripNote] = []
    @State private var manage = false
    @State private var photoEditor = false
    @State private var busy = false
    @State private var error: String?
    @State private var invitation: URL?
    @State private var text = ""
    @State private var editing: TripNote?
    @State private var noteID = UUID().uuidString.lowercased()
    private var path: String { "/trips/\(trip.id)" }
    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text("Попутчики").font(.title2.bold())
            if let team {
                ForEach(team.people.filter { $0.id == team.ownerId || team.memberIds.contains($0.id) }) { p in
                    Label(p.name + (p.id == team.ownerId ? " · автор":""),systemImage:"person.crop.circle")
                }
                if team.ownerId == club.member?.id {
                    DisclosureGroup("Добавить попутчиков",isExpanded:$manage) {
                        VStack(alignment:.leading,spacing:12) {
                            Text("Поездку видит весь клуб. Попутчики могут добавлять свои фото и заметки.").font(.footnote)
                            ForEach(team.people.filter{$0.id != team.ownerId}) { p in
                                HStack { VStack(alignment:.leading){Text(p.name);Text("@"+p.username).font(.caption)};Spacer()
                                    Button(team.memberIds.contains(p.id) ? "Убрать":"Добавить") { Task { await change(p,remove:team.memberIds.contains(p.id)) } }.disabled(busy)
                                }
                            }
                            Button("Создать приглашение в поездку") { Task { await invite() } }.disabled(busy)
                            Text("Одноразовая ссылка на 7 дней.").font(.caption)
                            if let invitation { ShareLink(item:invitation){Label("Поделиться",systemImage:"square.and.arrow.up")};Text(invitation.absoluteString).font(.caption).textSelection(.enabled) }
                        }.padding(.vertical)
                    }
                }
                ForEach(notes) { note in
                    VStack(alignment:.leading,spacing:8) { Text(note.author).font(.headline);Text(note.body).textSelection(.enabled)
                        if note.author_id == club.member?.id && team.canContribute { Button("Изменить свою заметку"){editing=note;text=note.body}.disabled(busy) }
                    }.padding().frame(maxWidth:.infinity,alignment:.leading).background(.quaternary,in:RoundedRectangle(cornerRadius:12))
                }
                if team.canContribute {
                    TextField(editing == nil ? "Добавить свою заметку":"Изменить заметку",text:$text,axis:.vertical).lineLimit(3...10).textFieldStyle(.roundedBorder).disabled(busy)
                    Button("Сохранить заметку") { Task { await saveNote() } }.buttonStyle(.bordered).disabled(busy || text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || text.count>10000)
                    if editing != nil { Button("Отмена"){editing=nil;text=""}.disabled(busy) }
                    Button("Добавить свои фотографии",systemImage:"photo.badge.plus"){photoEditor=true}.buttonStyle(.bordered)
                }
            }
            if let error { Text(error).foregroundStyle(.red);Button("Обновить попутчиков"){Task{await load()}}.disabled(busy) }
        }.task{await load()}.sheet(isPresented:$photoEditor){JourneyEditor(club:club,trip:trip,photosOnly:true)}
    }
    private func load() async { do { let t:TripTeam = try await club.api(path+"/team");let n:TripNotes = try await club.api(path+"/notes");team=t;notes=n.notes;error=nil } catch {self.error=error.localizedDescription} }
    private func change(_ person:TripPerson,remove:Bool) async {busy=true;defer{busy=false};do{_=try await club.request(path+"/team",body:["userId":person.id,"remove":remove]);await load()}catch{self.error=error.localizedDescription}}
    private func invite() async {busy=true;defer{busy=false};do{let r:InviteResponse=try await club.api(path+"/trip-invite",body:[:]);invitation=URL(string:ClubModel.origin+"/#trip-invite="+r.token)}catch{self.error=error.localizedDescription}}
    private func saveNote() async {busy=true;defer{busy=false};do{var b:[String:Any]=["id":editing?.id ?? noteID,"body":text];if let editing{b["version"]=editing.version};_=try await club.request(path+"/notes",body:b);text="";editing=nil;noteID=UUID().uuidString.lowercased();await load()}catch{self.error=error.localizedDescription}}
}
struct JoinJourneyView: View {
    @ObservedObject var club: ClubModel
    @State private var link=""
    @State private var busy=false
    @State private var error:String?
    @State private var joined:Journey?
    var body:some View {
        Form {
            Text("Вставьте приглашение в конкретную поездку.")
            TextField("Ссылка приглашения",text:$link).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Присоединиться") { Task {busy=true;defer{busy=false};do{guard let token=clubToken(link,key:"trip-invite") else {throw ClubError(message:"Проверьте ссылку приглашения.")};let r:TripJoined=try await club.api("/trip-invites/accept",body:["token":token]);await club.refresh();joined=club.journeys.first{$0.id==r.tripId};if joined == nil {throw ClubError(message:"Вы присоединились. Обновите список путешествий.")}}catch{self.error=error.localizedDescription}} }.disabled(busy || clubToken(link,key:"trip-invite")==nil)
            if let error{Text(error).foregroundStyle(.red)}
        }.modifier(SheetHeader(title:"Приглашение в поездку"))
        .sheet(item:$joined){trip in NavigationStack{JourneyView(club:club,original:trip).toolbar{Button("Закрыть"){joined=nil}}}}
    }
}
struct NotificationsView: View {
    @ObservedObject var club:ClubModel
    @State private var busy=false
    var body:some View {
        List {
            if let error=club.notificationsError{Text(error).foregroundStyle(.red)}
            if club.notifications.isEmpty{Text("Пока нет уведомлений.")}
            ForEach(club.notifications){n in
                VStack(alignment:.leading,spacing:10){
                    Label(n.inviter+" добавил(а) вас в попутчики",systemImage:n.read_at == nil ? "bell.badge.fill":"bell")
                    Text(n.title).font(.headline)
                    if let trip=club.journeys.first(where:{$0.id==n.trip_id}){
                        NavigationLink("Открыть путешествие"){JourneyView(club:club,original:trip).task{await club.readNotice(n)}}
                    }
                    if n.read_at == nil{Button("Прочитано"){Task{busy=true;await club.readNotice(n);busy=false}}.disabled(busy)}
                }.padding(.vertical,8)
            }
        }.navigationTitle("Уведомления").task{await club.refresh();await club.refreshNotifications()}.refreshable{await club.refresh();await club.refreshNotifications()}
    }
}
