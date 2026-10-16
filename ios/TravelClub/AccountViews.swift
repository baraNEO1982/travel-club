import SwiftUI

struct RegistrationView: View {
    @ObservedObject var club: ClubModel
    @Environment(\.dismiss) private var dismiss
    @State private var invitation = ""
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    var body: some View {
        Form {
            Section { Text("Вставьте одноразовую ссылку, которую вам прислал участник клуба.")
                TextField("Ссылка приглашения", text: $invitation).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                if !invitation.isEmpty && clubToken(invitation, key: "invite") == nil { Text("Нужна ссылка приглашения клуба или код из неё.").foregroundStyle(.red) }
            }
            Section("Ваша учётная запись") {
                TextField("Имя", text: $name).textContentType(.name)
                TextField("Логин", text: $username).textContentType(.username).keyboardType(.asciiCapable).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Пароль — от 12 символов", text: $password).textContentType(.newPassword)
                Text("Логин: 3–32 латинские буквы, цифры или _. Пароль: 12–128 символов.").font(.caption)
            }
            if let error = club.error { Text(error).foregroundStyle(.red) }
            Button(club.busy ? "Регистрируем…" : "Зарегистрироваться") {
                guard let token = clubToken(invitation, key: "invite") else { return }
                Task { await club.authenticate(username: username, password: password, name: name, invite: token); if club.member != nil { password = ""; dismiss() } }
            }.disabled(club.busy || clubToken(invitation, key: "invite") == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 80 || username.range(of: "^[a-zA-Z0-9_]{3,32}$", options: .regularExpression) == nil || password.count < 12 || password.count > 128)
        }.disabled(club.busy).modifier(SheetHeader(title: "Регистрация по приглашению"))
    }
}
struct InviteView: View {
    @ObservedObject var club: ClubModel
    @State private var link: URL?
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        Form {
            Text("Приглашение одноразовое и действует 7 дней. Приглашённый сможет писать рассказы, комментировать и приглашать близких.")
            if let link {
                Text(link.absoluteString).font(.footnote).textSelection(.enabled)
                ShareLink(item: link) { Label("Поделиться приглашением", systemImage: "square.and.arrow.up") }
            }
            Button(busy ? "Создаём…" : link == nil ? "Создать приглашение" : "Создать ещё одно приглашение") {
                Task {
                    busy = true; error = nil; defer { busy = false }
                    do { let result: InviteResponse = try await club.api("/invites", body: [:]); link = URL(string: ClubModel.origin + "/#invite=" + result.token) }
                    catch { self.error = error.localizedDescription }
                }
            }.disabled(busy)
            if let error { Text(error).foregroundStyle(.red) }
        }.modifier(SheetHeader(title: "Пригласить близкого"))
    }
}
struct RecoveryView: View {
    @ObservedObject var club: ClubModel
    let mode: ClubSheet
    @State private var email = ""
    @State private var password = ""
    @State private var repeated = ""
    @State private var link = ""
    @State private var enabled = false
    @State private var ready = false
    @State private var busy = false
    @State private var done = false
    @State private var currentEmail: String?
    @State private var error: String?
    @State private var notice: String?
    @State private var next: ClubSheet?
    private var title: String { switch mode { case .profile: return "Моя почта"; case .reset: return "Новый пароль"; case .verify: return "Подтвердить почту"; default: return "Забыли пароль?" } }
    var body: some View {
        Form {
            if !ready && busy { ProgressView("Проверяем…") }
            if ready && !enabled { Text("Отправка писем ещё не подключена. Восстановление по почте пока недоступно.") }
            if mode == .profile { Text(currentEmail.map { "Подтверждённая почта: " + $0 } ?? "Подтверждённой почты пока нет.") }
            if mode == .forgot { Text("Укажите почту, которую вы ранее подтвердили в клубе. Если почта не была подтверждена, восстановить пароль по ней нельзя.") }
            if !done {
                Section {
                    if mode == .profile || mode == .forgot { TextField("Электронная почта", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled() }
                    if mode == .verify || mode == .reset { TextField("Ссылка из письма", text: $link).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled() }
                    if mode == .profile || mode == .reset { SecureField(mode == .profile ? "Текущий пароль" : "Новый пароль", text: $password).textContentType(mode == .profile ? .password : .newPassword) }
                    if mode == .reset { SecureField("Повторите новый пароль", text: $repeated).textContentType(.newPassword) }
                    Button(busy ? "Подождите…" : mode == .verify ? "Подтвердить почту" : mode == .reset ? "Сохранить пароль" : "Отправить письмо") { Task { await submit() } }
                }.disabled(busy || !ready || !enabled)
            }
            if let error { Text(error).foregroundStyle(.red) }
            if let notice { Text(notice) }
            if !ready && !busy { Button("Повторить проверку") { Task { await load() } } }
            if mode == .forgot { Button("Уже есть письмо для сброса пароля") { next = .reset } }
            if mode == .profile { Button("Уже есть письмо для подтверждения") { next = .verify } }
        }.modifier(SheetHeader(title: title)).task { await load() }
        .sheet(item: $next) { selected in RecoveryView(club: club, mode: selected) }
    }
    private func load() async {
        if mode == .reset || mode == .verify { enabled = true; ready = true; return }
        busy = true; error = nil; defer { busy = false }
        do { let result: EmailStatus = try await club.api(mode == .profile ? "/account/email" : "/recovery/status"); enabled = result.enabled; currentEmail = result.email; ready = true }
        catch { self.error = error.localizedDescription }
    }
    private func submit() async {
        guard !busy else { return }; error = nil; notice = nil
        if mode == .profile || mode == .reset {
            guard (12...128).contains(password.count) else { error = "Пароль: от 12 до 128 символов."; return }
        }
        if mode == .reset && password != repeated { error = "Пароли не совпадают."; return }
        let key = mode == .verify ? "verify-email" : "reset-password"
        let token = clubToken(link, key: key)
        if (mode == .verify || mode == .reset) && token == nil { error = "Вставьте полную ссылку из письма клуба."; return }
        busy = true; defer { busy = false }
        let path: String
        switch mode { case .profile: path = "/account/email"; case .reset: path = "/password/reset"; case .verify: path = "/email/confirm"; default: path = "/password/request" }
        do {
            let result: MessageResponse = try await club.api(path, body: ["email": email, "password": password, "token": token ?? ""])
            notice = result.message; password = ""; repeated = ""
            if mode == .reset || mode == .verify { done = true }
            if mode == .reset { club.clearSession() }
            if mode == .verify { await club.refresh() }
        } catch { self.error = error.localizedDescription }
    }
}
