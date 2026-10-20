import Foundation
import Combine
import FirebaseCore
import FirebaseAI
import FirebaseAuth

@MainActor
final class ChatController: ObservableObject {
    @Published var record = ChatRecord()
    @Published var busy = false
    @Published var notice: String?
    @Published var signedIn = false
    private var request: Task<Void, Never>?
    private var requestID: UUID?
    private var disk: ChatDisk?
    private var storageReadable = true
    var configured: Bool { FirebaseApp.app() != nil }

    init() {
        guard configured, let user = Auth.auth().currentUser else { return }
        signedIn = true
        openStorage(uid: user.uid)
    }
    private func openStorage(uid: String) {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        disk = ChatDisk(url: folder.appendingPathComponent("unifi/\(uid).json"))
        do { record = try disk!.load(); storageReadable = true }
        catch { storageReadable = false; notice = "Saved chat could not be read. Clear it explicitly before creating new messages." }
    }
    func signIn(email: String, password: String) async {
        guard configured else { notice = "Connect Firebase in the build configuration first."; return }
        busy = true
        defer { busy = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            signedIn = true
            notice = nil
            openStorage(uid: result.user.uid)
        } catch { notice = "Sign-in failed. Check your account and network connection." }
    }
    func signOut() {
        stop()
        do { try Auth.auth().signOut(); signedIn = false; record = ChatRecord(); disk = nil }
        catch { notice = "Could not sign out. Please retry." }
    }
    func clear() {
        stop()
        record = ChatRecord()
        storageReadable = true
        persist()
    }
    private func persist() {
        guard storageReadable else { return }
        do { try disk?.save(record) }
        catch { notice = "Chat could not be saved on this device." }
    }
    func stop() {
        requestID = nil
        request?.cancel()
        request = nil
        busy = false
        persist()
    }
    @discardableResult
    func send(_ input: String, modelName: String, location: String, instruction: String) -> Bool {
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !prompt.isEmpty, signedIn, storageReadable else { return false }
        let modelID = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modelID.isEmpty, !location.isEmpty else {
            notice = "Set an enabled model ID and region in Settings."; return false
        }
        let history = record.replayableMessages.map { ModelContent(role: $0.role, parts: $0.text) }
        record.messages.append(ChatMessage(role: "user", text: prompt))
        let reply = ChatMessage(role: "model", text: "", complete: false)
        record.messages.append(reply)
        persist()
        busy = true
        notice = nil
        let token = UUID()
        requestID = token
        request = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.requestID == token {
                    self.busy = false
                    self.requestID = nil
                    self.request = nil
                    self.persist()
                }
            }
            do {
                let ai = FirebaseAI.firebaseAI(backend: .vertexAI(location: location))
                let model = ai.generativeModel(modelName: modelID,
                    systemInstruction: instruction.isEmpty ? nil : ModelContent(role: "system", parts: instruction))
                let chat = model.startChat(history: history)
                let stream = try chat.sendMessageStream(prompt)
                for try await chunk in stream {
                    try Task.checkCancellation()
                    guard self.requestID == token,
                          let index = self.record.messages.firstIndex(where: { $0.id == reply.id }) else { return }
                    self.record.messages[index].text += chunk.text ?? ""
                }
                guard self.requestID == token,
                      let index = self.record.messages.firstIndex(where: { $0.id == reply.id }) else { return }
                if self.record.messages[index].text.isEmpty {
                    self.notice = "No text returned. The request may have been blocked or the model may not support this input."
                } else { self.record.messages[index].complete = true }
            } catch {
                guard self.requestID == token else { return }
                self.notice = RequestFailure.message(for: error)
            }
        }
        return true
    }
}
