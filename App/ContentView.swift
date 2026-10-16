import SwiftUI

struct ContentView: View {
    @StateObject private var chat = ChatController()
    @State private var prompt = ""
    @State private var email = ""
    @State private var password = ""
    @State private var settings = false
    @State private var confirmClear = false
    @AppStorage("modelID") private var modelID = ""
    @AppStorage("region") private var region = "us-central1"
    @AppStorage("systemInstruction") private var instruction = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !chat.configured {
                    ContentUnavailableView("Connect your AI workspace", systemImage: "sparkles",
                        description: Text("This build needs its Firebase configuration. Follow docs/IPHONE_SETUP.md in the repository."))
                } else if !chat.signedIn {
                    Form {
                        Section("Your unifi account") {
                            TextField("Email", text: $email).textContentType(.username)
                                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                            SecureField("Password", text: $password).textContentType(.password)
                            Button("Sign in") {
                                Task { await chat.signIn(email: email, password: password); password = "" }
                            }.disabled(chat.busy || email.isEmpty || password.isEmpty)
                        }
                        Text("Use the account created by your Firebase project administrator. Prompts are sent to Google when you tap Send; chat history stays on this device.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 20) {
                                if chat.record.messages.isEmpty {
                                    ContentUnavailableView("A little curiosity. Unlimited directions.", systemImage: "sparkles",
                                        description: Text("Choose your model in Settings, then start a conversation."))
                                }
                                ForEach(chat.record.messages) { message in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(message.role == "user" ? "You" : "unifi")
                                            .font(.caption.bold()).foregroundStyle(.secondary)
                                        Text(.init(message.text.isEmpty ? "…" : message.text)).textSelection(.enabled)
                                        if !message.complete && !chat.busy {
                                            Text("Incomplete reply").font(.caption).foregroundStyle(.secondary)
                                        }
                                        if !message.text.isEmpty { ShareLink(item: message.text) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Share message") }
                                    }
                                    .padding().frame(maxWidth: .infinity, alignment: .leading)
                                    .background(message.role == "user" ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                }
                                Color.clear.frame(height: 1).id("bottom")
                            }.padding()
                        }
                        .onChange(of: chat.record.messages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    HStack(alignment: .bottom) {
                        TextField("Ask anything", text: $prompt, axis: .vertical).lineLimit(1...6)
                        if chat.busy {
                            Button("Stop", systemImage: "stop.fill") { chat.stop() }.labelStyle(.iconOnly)
                        } else {
                            Button("Send", systemImage: "arrow.up.circle.fill") {
                                if chat.send(prompt, modelName: modelID, location: region, instruction: instruction) { prompt = "" }
                            }.labelStyle(.iconOnly).font(.title2).disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }.padding().background(.bar)
                }
                if let notice = chat.notice {
                    Text(notice).font(.footnote).foregroundStyle(.orange).padding().accessibilityAddTraits(.updatesFrequently)
                }
            }
            .navigationTitle("unifi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Settings", systemImage: "slider.horizontal.3") { settings = true } }
            }
            .sheet(isPresented: $settings) {
                NavigationStack {
                    Form {
                        Section("Google Cloud model") {
                            TextField("Enabled model ID", text: $modelID).textInputAutocapitalization(.never).autocorrectionDisabled()
                            TextField("Region", text: $region).textInputAutocapitalization(.never).autocorrectionDisabled()
                            Text("Use a model and region enabled in your own project. Availability and usage charges are determined by Google.").font(.footnote)
                        }
                        Section("System instructions") { TextEditor(text: $instruction).frame(minHeight: 120) }
                        if chat.signedIn {
                            Section("Local data") {
                                Button("Clear conversation", role: .destructive) { confirmClear = true }
                                Button("Sign out") { chat.signOut(); settings = false }
                            }
                        }
                    }.navigationTitle("Settings")
                    .toolbar { Button("Done") { settings = false } }
                    .confirmationDialog("Delete this device’s saved conversation?", isPresented: $confirmClear, titleVisibility: .visible) {
                        Button("Delete conversation", role: .destructive) { chat.clear() }
                    }
                }
            }
        }.tint(.indigo)
    }
}
