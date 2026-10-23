import SwiftUI

let clubNavy = Color(red: 0.09, green: 0.23, blue: 0.30)
@main struct TravelClubApp: App {
    var body: some Scene { WindowGroup { ClubView() } }
}
struct ClubView: View {
    @StateObject private var club: ClubModel
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-fixture") {
            let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[PreviewTransport.self]
            let model=ClubModel(session:URLSession(configuration:config));model.member=Member(id:"demo-owner",name:"Автор")
            _club=StateObject(wrappedValue:model)
        } else {_club=StateObject(wrappedValue:ClubModel())}
        #else
        _club=StateObject(wrappedValue:ClubModel())
        #endif
    }
    @State private var sheet: ClubSheet?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            Group {
                if let member = club.member {
                    List {
                        Section { Text("Привет, \(member.name)") }
                        Section {
                            NavigationLink { NotificationsView(club:club) } label: { Label("Уведомления (\(club.notifications.filter{$0.read_at == nil}.count))",systemImage:"bell") }
                            ForEach(club.notifications.filter{$0.read_at == nil}) { n in
                                if let trip=club.journeys.first(where:{$0.id==n.trip_id}) { NavigationLink {JourneyView(club:club,original:trip).task{await club.readNotice(n)}} label:{VStack(alignment:.leading){Text(n.inviter+" добавил(а) вас в попутчики").font(.caption);Text(n.title).bold()}} }
                            }
                        }
                        if club.loadingJourneys { ProgressView("Загружаем путешествия…") }
                        if let error = club.journeysError {
                            Section { Text(error).foregroundStyle(.red); Button("Повторить загрузку") { Task { await club.refresh() } } }
                        }
                        if club.journeysLoaded && club.journeys.isEmpty && club.journeysError == nil && !club.loadingJourneys {
                            Text("Путешествий пока нет. Добавьте свою первую историю.")
                        }
                        ForEach(club.journeys) { trip in
                            NavigationLink { JourneyView(club: club, original: trip) } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    if let photo = trip.photos.first { PrivatePhoto(club: club, path: photo).frame(maxHeight: 200).clipped() }
                                    Text(trip.title).font(.title3.bold())
                                    Text(trip.place).foregroundStyle(.secondary)
                                    Text(Date(timeIntervalSince1970: trip.created_at), style: .date).font(.caption)
                                }.padding(.vertical, 8)
                            }
                        }
                    }
                    .navigationTitle("Путешествия")
                    .refreshable { await club.refresh() }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Menu {
                                Button("Пригласить близкого") { sheet = .invite }
                                Button("Приглашение в поездку") {sheet = .join}
                                Button("Моя почта") { sheet = .profile }
                                Button("Выйти") { Task { await club.logout() } }.disabled(club.busy || club.loadingJourneys)
                            } label: { Label("Участник", systemImage: "person.crop.circle") }
                        }
                        ToolbarItem(placement: .topBarTrailing) { Button { sheet = .write } label: { Label("Добавить путешествие", systemImage: "plus") } }
                    }
                } else { LoginView(club: club, sheet: $sheet) }
            }
            .safeAreaInset(edge: .bottom) { if let error = club.error { Text(error).font(.footnote).foregroundStyle(.red).padding().frame(maxWidth: .infinity).background(.regularMaterial) } }
        }
        .id(club.member?.id ?? "guest")
        .tint(clubNavy)
        .task(id:club.member?.id) {await club.refresh();while club.member != nil && !Task.isCancelled {if scenePhase == .active{await club.refreshNotifications()};do{try await Task.sleep(for:.seconds(60))}catch{break}}}
        .onChange(of:scenePhase){_,phase in if phase == .active && club.member != nil{Task{await club.refreshNotifications()}}}
        .sheet(item: $sheet) { selected in
            switch selected {
            case .join: JoinJourneyView(club:club)
            case .write: JourneyEditor(club: club, trip: nil)
            case .invite: InviteView(club: club)
            case .register: RegistrationView(club: club)
            case .profile, .forgot, .reset, .verify: RecoveryView(club: club, mode: selected)
            }
        }
    }
}
enum ClubSheet: String, Identifiable { case join, write, invite, register, profile, forgot, reset, verify; var id: String { rawValue } }
struct LoginView: View {
    @ObservedObject var club: ClubModel
    @Binding var sheet: ClubSheet?
    @State private var username = ""
    @State private var password = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let imageURL = Bundle.main.url(forResource:"bureya-hero",withExtension:"jpg"), let image = UIImage(contentsOfFile:imageURL.path) {Image(uiImage:image).resizable().scaledToFill().frame(height:190).clipped().clipShape(RoundedRectangle(cornerRadius:16)).accessibilityLabel("Бурея, Амурская область")}
                Image(systemName: "safari").font(.system(size: 56)).foregroundStyle(clubNavy)
                Text("Клуб\nпутешественников").font(.largeTitle.bold())
                Text("Свои люди. Целый мир.").foregroundStyle(.secondary)
                Text("Сохраняйте маршруты, фотографии и воспоминания в кругу близких.")
                TextField("Логин", text: $username).textContentType(.username).keyboardType(.asciiCapable).textInputAutocapitalization(.never).autocorrectionDisabled().textFieldStyle(.roundedBorder)
                PasswordField("Пароль", text: $password).textFieldStyle(.roundedBorder)
                Button(club.busy ? "Входим…" : "Войти в клуб") {
                    Task { await club.authenticate(username: username, password: password); if club.member != nil { password = "" } }
                }.buttonStyle(.borderedProminent).disabled(club.busy || username.isEmpty || password.isEmpty)
                Button("У меня приглашение — зарегистрироваться") { club.error = nil; sheet = .register }
                Button("Забыли пароль?") { club.error = nil; sheet = .forgot }
                Text("Только по приглашению участника.").font(.footnote).foregroundStyle(.secondary)
            }.padding(28)
        }
    }
}
struct SheetHeader: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let title: String
    func body(content: Content) -> some View { NavigationStack { content.navigationTitle(title).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } }
}
