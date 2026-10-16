import SwiftUI
import UIKit

/// Create a group (SOC-01): name and emoji, then the invite screen.
struct CreateGroupView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🏋️"
    @State private var created: LeagueGroup?
    @State private var draft = LeagueModeDraft()
    @FocusState private var nameFocused: Bool

    static let emojis = ["🏋️", "💪", "🔥", "🏆", "⚡️", "🦍", "🐺", "🥇", "🏢", "🎓", "🏃", "🧗"]

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        HStack(spacing: 12) {
                            GroupEmoji(emoji: emoji, size: 44)
                            TextField("Group name", text: $name)
                                .font(.title3)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .accessibilityIdentifier("groupNameField")
                        }
                    } footer: {
                        Text("\(name.trimmingCharacters(in: .whitespacesAndNewlines).count)/\(LeagueStore.nameRange.upperBound) · for example Office Lifters")
                            .monospacedDigit()
                    }
                    Section("Icon") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(Self.emojis, id: \.self) { option in
                                Button {
                                    emoji = option
                                } label: {
                                    Text(option)
                                        .font(.title2)
                                        .frame(maxWidth: .infinity, minHeight: Theme.minTap)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(option == emoji ? Theme.accent.opacity(0.18) : .clear)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(option == emoji ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    LeagueModeSections(draft: $draft)
                    Section {
                        Text("You become the group's admin and can change the league later; changes start the following Monday.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Theme.listRow)
            }
            .screenBackground()
            .navigationTitle("New group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        created = env.leagues.createGroup(name: name, emoji: emoji, mode: draft.mode)
                    }
                    .disabled(!LeagueStore.isValidName(name) || !draft.isValid)
                    .accessibilityIdentifier("createGroupConfirm")
                }
            }
            .navigationDestination(item: $created) { group in
                InviteView(group: group, onDone: { dismiss() })
                    .navigationBarBackButtonHidden()
            }
            .onAppear { nameFocused = true }
        }
    }
}

/// Invite code and share link (SOC-02, appendix A.9).
struct InviteView: View {
    @Environment(\.dismiss) private var dismiss
    let group: LeagueGroup
    var onDone: (() -> Void)?
    @State private var copied = false

    private var link: URL { URL(string: "https://rivalift.app/join/\(group.inviteCode)")! }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                GroupEmoji(emoji: group.emoji, size: 64)
                Text(group.name).font(.title2.bold())
                Text("Friends join with this code or the link.").foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                ForEach(Array(group.inviteCode.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .frame(width: 44, height: 56)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "Invite code \(group.inviteCode.map(String.init).joined(separator: " "))"))
            .accessibilityIdentifier("inviteCode")

            Button {
                UIPasteboard.general.string = group.inviteCode
                copied = true
            } label: {
                Label(copied ? "Copied" : "Copy code", systemImage: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.secondary)

            ShareLink(item: link, message: Text("Join \(group.name) on Rivalift. Code: \(group.inviteCode)")) {
                Label("Share invite link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .screenBackground()
        .navigationTitle("Invite friends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone?() ?? dismiss() }
            }
        }
    }
}

/// Join with a 6-character code, confirm the group first (SOC-03, appendix A.9).
struct JoinGroupView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @FocusState private var focused: Bool

    var body: some View {
        let preview = env.leagues.preview(code: code)
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Enter the 6-character code a friend shared with you.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    codeBoxes
                        .onTapGesture { focused = true }

                    PasteButton(payloadType: String.self) { strings in
                        if let text = strings.first { code = InviteCode.normalize(text) }
                    }
                    .labelStyle(.titleAndIcon)

                    if code.count == InviteCode.length && preview == nil {
                        Text("Code not found. Check the letters and try again.")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }

                    if let preview {
                        groupPreview(preview)
                    }
                }
                .padding(24)
            }
            .screenBackground()
            .navigationTitle("Join a group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear { focused = true }
        }
    }

    /// Six boxes over a hidden text field, so typing, paste and autofill all work.
    private var codeBoxes: some View {
        ZStack {
            TextField("", text: Binding(get: { code }, set: { code = InviteCode.normalize($0) }))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .accessibilityLabel("Invite code")
                .accessibilityIdentifier("joinCodeField")
            HStack(spacing: 6) {
                ForEach(0..<InviteCode.length, id: \.self) { index in
                    let character = index < code.count ? String(Array(code)[index]) : ""
                    Text(character)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .frame(width: 44, height: 56)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(focused && index == min(code.count, InviteCode.length - 1) ? Theme.accent : .clear, lineWidth: 2)
                        )
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func groupPreview(_ group: LeagueGroup) -> some View {
        let isMember = env.leagues.isMember(of: group)
        return VStack(spacing: 14) {
            HStack(spacing: 14) {
                GroupEmoji(emoji: group.emoji, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name).font(.headline)
                    Text("\(group.memberCount - (isMember ? 0 : 1)) members").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: -8) {
                ForEach(group.friends.prefix(5)) { friend in
                    AvatarView(name: friend.name, size: 32)
                        .overlay(Circle().stroke(.black, lineWidth: 2))
                }
                Spacer()
            }
            if isMember {
                Text("You're already in this group.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Button("Join \(group.name)") {
                    env.leagues.join(group)
                    dismiss()
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("joinGroupConfirm")
            }
        }
        .card()
    }
}
