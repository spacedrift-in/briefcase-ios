import SwiftUI
import SpacedriftCore

// MARK: - Local demo models

enum DemoRole: String, CaseIterable, Identifiable {
    case client = "Client reviewer"
    case consultant = "Consultant"
    case guest = "Restricted account"

    var id: String { rawValue }
    var subject: String {
        switch self {
        case .client: "demo-client"
        case .consultant: "demo-consultant"
        case .guest: "demo-guest"
        }
    }

    var shortName: String {
        switch self {
        case .client: "Client"
        case .consultant: "Consultant"
        case .guest: "Restricted"
        }
    }

    static func name(for subject: String) -> String {
        switch subject {
        case DemoRole.client.subject: DemoRole.client.rawValue
        case DemoRole.consultant.subject: DemoRole.consultant.rawValue
        default: "Demo account"
        }
    }
}

struct DemoProject: Identifiable, Hashable {
    let id: UUID
    let name: String
    let summary: String
    let isRestricted: Bool
}

struct DemoVersion: Identifiable, Equatable {
    let id: UUID
    let number: Int
    let fileName: String
    let author: String
    let createdAt: Date
    var review: ReviewState
    var comment: String?
}

struct DemoAudit: Identifiable, Equatable {
    let id = UUID()
    let versionID: UUID
    let versionNumber: Int
    let actor: String
    let action: String
    let comment: String?
    let date: Date
}

@MainActor
protocol ReviewWorkflowRepository: ObservableObject {
    var role: DemoRole { get set }
    var versions: [DemoVersion] { get }
    var audit: [DemoAudit] { get }
    var notice: String? { get set }
    func canOpen(_ project: DemoProject) -> Bool
    func decide(version: DemoVersion, approve: Bool, comment: String)
    func createRevision()
}

@MainActor
final class DemoStore: ReviewWorkflowRepository {
    @Published var role: DemoRole = .client
    @Published private(set) var versions: [DemoVersion]
    @Published private(set) var audit: [DemoAudit]
    @Published var notice: String?

    let project = DemoProject(
        id: UUID(uuidString: "A115A11A-0090-4E1B-A305-401E73000001")!,
        name: "Northstar identity",
        summary: "Brand system · Client review",
        isRestricted: false
    )
    let restrictedProject = DemoProject(
        id: UUID(uuidString: "A115A11A-0090-4E1B-A305-401E73000002")!,
        name: "Confidential launch",
        summary: "Restricted project",
        isRestricted: true
    )

    init() {
        versions = [DemoVersion(
            id: UUID(uuidString: "B225B22B-0090-4E1B-A305-401E73000001")!,
            number: 1,
            fileName: "northstar-concept-v1.pdf",
            author: DemoRole.consultant.subject,
            createdAt: .now.addingTimeInterval(-86_400),
            review: .awaitingReview,
            comment: nil
        )]
        audit = []
    }

    func canOpen(_ project: DemoProject) -> Bool {
        !project.isRestricted || role == .consultant
    }

    func decide(version: DemoVersion, approve: Bool, comment: String) {
        guard role == .client else {
            notice = "Only the client reviewer can record a decision."
            return
        }
        guard let index = versions.firstIndex(where: { $0.id == version.id }) else { return }

        do {
            let decision: ReviewDecision = approve
                ? .approve(comment: comment.isEmpty ? nil : comment)
                : .requestChanges(comment: comment)
            versions[index].review = try versions[index].review.applying(decision)
            versions[index].comment = comment.isEmpty ? nil : comment
            audit.insert(DemoAudit(
                versionID: version.id,
                versionNumber: version.number,
                actor: role.subject,
                action: approve ? "Approved" : "Requested changes",
                comment: versions[index].comment,
                date: .now
            ), at: 0)
            notice = "Demo only · Version \(version.number) was saved on this device, not sent to a server."
        } catch {
            notice = "This version already has a final decision."
        }
    }

    func createRevision() {
        guard role == .consultant else {
            notice = "Only the consultant can create a revision."
            return
        }
        let next = (versions.map(\.number).max() ?? 0) + 1
        versions.insert(DemoVersion(
            id: UUID(),
            number: next,
            fileName: "northstar-concept-v\(next).pdf",
            author: role.subject,
            createdAt: .now,
            review: .awaitingReview,
            comment: nil
        ), at: 0)
        notice = "Demo only · Version \(next) is synthetic metadata saved on this device; no file was uploaded."
    }
}

@MainActor
final class VersionDetailModel: ObservableObject {
    @Published var isFeedbackPresented = false
    @Published var isApprovalConfirmationPresented = false
    @Published var comment = ""
}

// MARK: - Design system

private enum StudioStyle {
    static let paper = Color(red: 0.965, green: 0.957, blue: 0.933)
    static let surface = Color(red: 1.000, green: 0.998, blue: 0.990)
    static let surfaceMuted = Color(red: 0.944, green: 0.930, blue: 0.900)
    static let ink = Color(red: 0.145, green: 0.137, blue: 0.176)
    static let secondaryInk = Color(red: 0.424, green: 0.412, blue: 0.455)
    static let tertiaryInk = Color(red: 0.565, green: 0.545, blue: 0.576)
    static let separator = Color(red: 0.875, green: 0.855, blue: 0.816)
    static let indigo = Color(red: 0.302, green: 0.267, blue: 0.620)
    static let indigoWash = Color(red: 0.922, green: 0.910, blue: 0.980)
    static let green = Color(red: 0.224, green: 0.400, blue: 0.314)
    static let greenWash = Color(red: 0.902, green: 0.945, blue: 0.910)
    static let rust = Color(red: 0.588, green: 0.298, blue: 0.235)
    static let rustWash = Color(red: 0.973, green: 0.918, blue: 0.875)
    static let gold = Color(red: 0.525, green: 0.392, blue: 0.165)
    static let goldWash = Color(red: 0.969, green: 0.941, blue: 0.855)

    static let pageInset: CGFloat = 20
    static let sectionGap: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 13
}

private extension View {
    func studioSurface(cornerRadius: CGFloat = 20, color: Color = StudioStyle.surface) -> some View {
        background(color, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct StudioButtonStyle: ButtonStyle {
    enum Tone {
        case primary
        case secondary
        case quiet
    }

    var tone: Tone = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(background, in: RoundedRectangle(cornerRadius: StudioStyle.controlRadius, style: .continuous))
            .overlay {
                if tone == .secondary {
                    RoundedRectangle(cornerRadius: StudioStyle.controlRadius, style: .continuous)
                        .stroke(StudioStyle.separator.opacity(0.75), lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.48)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .primary: .white
        case .secondary, .quiet: StudioStyle.ink
        }
    }

    private var background: Color {
        switch tone {
        case .primary: StudioStyle.indigo
        case .secondary: StudioStyle.surface
        case .quiet: .clear
        }
    }
}

private struct StudioLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct Eyebrow: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.25)
                .foregroundStyle(StudioStyle.tertiaryInk)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(StudioStyle.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DemoRoleMenu: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        Menu {
            Section("Switch demo account") {
                Picker("Demo account", selection: $store.role) {
                    ForEach(DemoRole.allCases) { role in
                        Text(role.rawValue).tag(role)
                    }
                }
            }
            Text("Local fixtures only · no server session")
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 13))
                Text("Demo · \(store.role.shortName)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(StudioStyle.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(minHeight: 44)
            .contentShape(Capsule())
            .background(StudioStyle.surface, in: Capsule())
            .overlay(Capsule().stroke(StudioStyle.separator.opacity(0.8), lineWidth: 1))
        }
        .accessibilityLabel("Demo account: \(store.role.rawValue). Change account")
        .accessibilityIdentifier("demo-role-menu")
    }
}

private struct BrandHeader: View {
    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(StudioStyle.ink)
                    .frame(width: 31, height: 31)
                Image(systemName: "sparkle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(StudioStyle.paper)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("SPACEDRIFT")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(StudioStyle.ink)
                Text("STUDIO APPROVALS")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(StudioStyle.tertiaryInk)
            }
            Spacer()
            DemoRoleMenu()
        }
        .padding(.top, 2)
        .accessibilityElement(children: .contain)
    }
}

private struct DemoNoticeBanner: View {
    let message: String
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(StudioStyle.indigo)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text("LOCAL DEMO")
                    .font(.caption2.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(StudioStyle.indigo)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(StudioStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(StudioStyle.secondaryInk)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss demo message")
        }
        .padding(14)
        .background(StudioStyle.indigoWash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct StatusPill: View {
    let state: ReviewState
    private var title: String {
        switch state {
        case .awaitingReview: "In review"
        case .approved: "Approved"
        case .changesRequested: "Changes requested"
        }
    }
    private var color: Color {
        switch state {
        case .awaitingReview: StudioStyle.gold
        case .approved: StudioStyle.green
        case .changesRequested: StudioStyle.rust
        }
    }
    private var wash: Color {
        switch state {
        case .awaitingReview: StudioStyle.goldWash
        case .approved: StudioStyle.greenWash
        case .changesRequested: StudioStyle.rustWash
        }
    }
    private var symbol: String {
        switch state {
        case .awaitingReview: "clock"
        case .approved: "checkmark"
        case .changesRequested: "arrow.uturn.backward"
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(title).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(wash, in: Capsule())
        .accessibilityLabel("Review status: \(title)")
        .accessibilityIdentifier("review-status-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }
}

private struct SectionTitle: View {
    let title: String
    var detail: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.system(.title3, design: .serif, weight: .medium))
                .foregroundStyle(StudioStyle.ink)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(StudioStyle.tertiaryInk)
            }
        }
    }
}

// MARK: - App entry and project overview

@main
struct SpacedriftApp: App {
    @StateObject private var store = DemoStore()
    @StateObject private var apiConnection = APIConnectionModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(apiConnection)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: DemoStore
    @EnvironmentObject private var apiConnection: APIConnectionModel

    var body: some View {
        ZStack {
            StudioStyle.paper.ignoresSafeArea()
            NavigationStack {
                ProjectListView()
                    .navigationDestination(for: DemoProject.self) { project in
                        ProjectDetailView(project: project)
                    }
            }
            .id(store.role)
            .background(.clear)
            .tint(StudioStyle.indigo)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StudioStyle.paper.ignoresSafeArea())
        .task { await apiConnection.refresh() }
    }
}

@MainActor
private final class APIConnectionModel: ObservableObject {
    enum State {
        case connecting
        case connected
        case unavailable
    }

    @Published private(set) var state: State = .connecting
    @Published private(set) var detail = "Checking API process…"
    @Published private(set) var isChecking = false

    private let client: ApprovalAPIClient?

    init() {
        let configuredURL = Bundle.main.object(forInfoDictionaryKey: "SpacedriftAPIBaseURL") as? String ?? ""
        if let configuration = try? APIConfiguration(baseURLString: configuredURL) {
            client = ApprovalAPIClient(configuration: configuration)
        } else {
            client = nil
            state = .unavailable
            detail = "API address is not configured for this build."
        }
    }

    func refresh() async {
        guard !isChecking else { return }
        guard let client else {
            state = .unavailable
            detail = "Set SpacedriftAPIBaseURL in the app Info.plist, then rebuild."
            return
        }

        isChecking = true
        state = .connecting
        detail = "Checking API process…"
        defer { isChecking = false }

        do {
            let live = try await client.liveness()
            guard live.status == "alive" else {
                state = .unavailable
                detail = "The API returned an unexpected liveness response."
                return
            }
            state = .connected

            do {
                let ready = try await client.readiness()
                detail = ready.status == "ready"
                    ? "API live · database ready · sign-in not configured"
                    : "API live · database readiness not confirmed · sign-in not configured"
            } catch {
                detail = "API live · database readiness unavailable · sign-in not configured"
            }
        } catch let error as ApprovalAPIError {
            state = .unavailable
            detail = error.errorDescription ?? "API unavailable. Check its address and retry."
        } catch {
            state = .unavailable
            detail = "API unavailable. Check its address and retry."
        }
    }
}

private struct APIConnectionIndicator: View {
    @EnvironmentObject private var apiConnection: APIConnectionModel

    private var color: Color {
        switch apiConnection.state {
        case .connecting: StudioStyle.gold
        case .connected: StudioStyle.green
        case .unavailable: StudioStyle.rust
        }
    }

    private var title: String {
        switch apiConnection.state {
        case .connecting: "Connecting"
        case .connected: "API live"
        case .unavailable: "Unavailable"
        }
    }

    var body: some View {
        Button {
            Task { await apiConnection.refresh() }
        } label: {
            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioStyle.ink)
                    Text(apiConnection.detail)
                        .font(.caption2)
                        .foregroundStyle(StudioStyle.secondaryInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if apiConnection.isChecking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioStyle.secondaryInk)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioStyle.surfaceMuted.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(StudioLinkStyle())
        .disabled(apiConnection.isChecking)
        .accessibilityLabel("\(title). \(apiConnection.detail). Tap to retry.")
    }
}

struct ProjectListView: View {
    @EnvironmentObject private var store: DemoStore

    private var outstandingCount: Int {
        store.versions.filter { $0.review == .awaitingReview }.count
    }

    var body: some View {
        ZStack {
            StudioStyle.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: StudioStyle.sectionGap) {
                    BrandHeader()
                    APIConnectionIndicator()

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Approvals")
                                .font(.system(.title2, design: .serif, weight: .medium))
                                .tracking(-0.4)
                                .foregroundStyle(StudioStyle.ink)
                            Text("Northstar Studio · Client review")
                                .font(.footnote)
                                .foregroundStyle(StudioStyle.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 4)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(outstandingCount > 0 ? StudioStyle.gold : StudioStyle.green)
                                .frame(width: 6, height: 6)
                            Text(outstandingCount == 1 ? "1 pending" : "\(outstandingCount) pending")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(StudioStyle.ink)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(outstandingCount > 0 ? StudioStyle.goldWash : StudioStyle.greenWash, in: Capsule())
                    }

                    NavigationLink {
                        if let pending = store.versions.first(where: { $0.review == .awaitingReview }) {
                            VersionDetailView(versionID: pending.id)
                        } else {
                            ProjectDetailView(project: store.project)
                        }
                    } label: {
                        ProjectFeature(project: store.project, outstandingCount: outstandingCount)
                    }
                    .buttonStyle(StudioLinkStyle())
                    .accessibilityIdentifier("project-northstar")

                    NavigationLink { ProjectDetailView(project: store.project) } label: {
                        HStack(spacing: 6) {
                            Text("Project overview")
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioStyle.indigo)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(StudioLinkStyle())
                    .accessibilityIdentifier("project-overview")

                    VStack(alignment: .leading, spacing: 11) {
                        SectionTitle(title: "Deliverables", detail: "Newest first")
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.versions.enumerated()), id: \.element.id) { index, version in
                                NavigationLink { VersionDetailView(versionID: version.id) } label: {
                                    DeliverableVersionRow(version: version)
                                }
                                .buttonStyle(StudioLinkStyle())
                                .accessibilityIdentifier("version-\(version.number)")
                                if index < store.versions.count - 1 {
                                    Rectangle().fill(StudioStyle.separator.opacity(0.65))
                                        .frame(height: 1)
                                        .padding(.leading, 58)
                                }
                            }
                        }
                        .padding(.horizontal, 13)
                        .studioSurface(cornerRadius: 17)
                        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(StudioStyle.separator.opacity(0.6), lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Demo access", detail: "Walkthrough")
                        RestrictedProjectRow(project: store.restrictedProject)
                    }

                    Text("Local demo · decisions stay on this device and are not server-confirmed.")
                        .font(.caption)
                        .foregroundStyle(StudioStyle.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, StudioStyle.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.automatic)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(StudioStyle.paper.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            if let notice = store.notice {
                DemoNoticeBanner(message: notice) { withAnimation(.easeInOut(duration: 0.2)) { store.notice = nil } }
                    .padding(.horizontal, StudioStyle.pageInset)
                    .padding(.top, 6)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ProjectFeature: View {
    let project: DemoProject
    let outstandingCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CLIENT PROJECT")
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(StudioStyle.tertiaryInk)
                    Text(project.name)
                        .font(.system(.title3, design: .serif, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(StudioStyle.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Maya Chen · Northstar Studio")
                        .font(.caption)
                        .foregroundStyle(StudioStyle.secondaryInk)
                }
                Spacer(minLength: 0)
                Image(systemName: outstandingCount > 0 ? "arrow.right" : "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(StudioStyle.indigo)
                    .frame(width: 34, height: 34)
                    .background(StudioStyle.indigoWash, in: Circle())
            }

            Rectangle().fill(StudioStyle.separator.opacity(0.8)).frame(height: 1)

            HStack(spacing: 7) {
                if outstandingCount > 0 {
                    StatusPill(state: .awaitingReview)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Up to date")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(StudioStyle.green)
                }
                Spacer(minLength: 2)
                HStack(spacing: 5) {
                    Text(outstandingCount > 0 ? "Review pending" : "Open project")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioStyle.indigo)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(StudioStyle.indigo)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(14)
        .studioSurface(cornerRadius: StudioStyle.cardRadius)
        .overlay(RoundedRectangle(cornerRadius: StudioStyle.cardRadius, style: .continuous).stroke(StudioStyle.separator.opacity(0.65), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: StudioStyle.cardRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the project and pending review")
    }
}

private struct RestrictedProjectRow: View {
    @EnvironmentObject private var store: DemoStore
    let project: DemoProject

    @ViewBuilder
    var body: some View {
        if store.canOpen(project) {
            NavigationLink(value: project) { rowLabel }
                .buttonStyle(StudioLinkStyle())
                .accessibilityHint("Opens the consultant demo project")
                .accessibilityIdentifier("restricted-project")
        } else {
            Button {
                store.notice = "Access denied · this demo account is not a member of this project."
            } label: {
                rowLabel
            }
            .buttonStyle(.plain)
            .buttonStyle(StudioLinkStyle())
            .accessibilityHint("Shows access denied for this account")
            .accessibilityIdentifier("restricted-project")
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 13) {
            Image(systemName: "lock.shield")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(StudioStyle.secondaryInk)
                .frame(width: 42, height: 42)
                .background(StudioStyle.surfaceMuted, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(StudioStyle.ink)
                    .multilineTextAlignment(.leading)
                Text(store.role == .consultant ? "Consultant access · tap to open" : "Restricted · tap to test access denial")
                    .font(.caption)
                    .foregroundStyle(StudioStyle.secondaryInk)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: store.role == .consultant ? "arrow.up.right" : "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(StudioStyle.tertiaryInk)
        }
        .padding(14)
        .studioSurface(cornerRadius: 17)
        .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(StudioStyle.separator.opacity(0.65), lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

// MARK: - Project overview and deliverables

struct ProjectDetailView: View {
    @EnvironmentObject private var store: DemoStore
    let project: DemoProject

    private var outstandingCount: Int {
        store.versions.filter { $0.review == .awaitingReview }.count
    }

    var body: some View {
        ZStack {
            StudioStyle.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("BRAND SYSTEM · CLIENT REVIEW")
                            .font(.caption2.weight(.bold))
                            .tracking(1.15)
                            .foregroundStyle(StudioStyle.tertiaryInk)
                        Text(project.name)
                            .font(.system(.title, design: .serif, weight: .medium))
                            .tracking(-0.35)
                            .foregroundStyle(StudioStyle.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Maya Chen · Northstar Studio")
                            .font(.subheadline)
                            .foregroundStyle(StudioStyle.secondaryInk)
                    }
                    .padding(.top, 4)

                    HStack(alignment: .center, spacing: 12) {
                        ProjectMetric(value: outstandingCount == 1 ? "01" : String(format: "%02d", outstandingCount), label: "AWAITING REVIEW")
                        Rectangle().fill(StudioStyle.separator).frame(width: 1, height: 38)
                        ProjectMetric(value: String(format: "%02d", store.versions.count), label: "VERSIONS")
                        Spacer(minLength: 2)
                        StatusPill(state: outstandingCount > 0 ? .awaitingReview : (store.versions.first?.review ?? .awaitingReview))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 13)
                    .studioSurface(cornerRadius: 17)
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(StudioStyle.separator.opacity(0.6), lineWidth: 1))

                    if let notice = store.notice {
                        DemoNoticeBanner(message: notice) { withAnimation(.easeInOut(duration: 0.2)) { store.notice = nil } }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "Deliverables", detail: "Newest first")
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.versions.enumerated()), id: \.element.id) { index, version in
                                NavigationLink { VersionDetailView(versionID: version.id) } label: {
                                    DeliverableVersionRow(version: version)
                                }
                                .buttonStyle(StudioLinkStyle())
                                if index < store.versions.count - 1 {
                                    Rectangle().fill(StudioStyle.separator.opacity(0.65)).frame(height: 1).padding(.leading, 68)
                                }
                            }
                        }
                        .padding(.horizontal, 15)
                        .studioSurface(cornerRadius: 19)
                        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(StudioStyle.separator.opacity(0.6), lineWidth: 1))
                    }

                    if store.role == .consultant {
                        Button { withAnimation(.easeInOut(duration: 0.2)) { store.createRevision() } } label: {
                            Label("Create synthetic revision", systemImage: "plus")
                        }
                        .buttonStyle(StudioButtonStyle(tone: .secondary))
                        .accessibilityHint("Creates a local version record. No file is uploaded.")
                        .accessibilityIdentifier("create-synthetic-revision")
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(title: "Project record")
                        NavigationLink { AuditView() } label: {
                            HStack(spacing: 13) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 17))
                                    .foregroundStyle(StudioStyle.indigo)
                                    .frame(width: 42, height: 42)
                                    .background(StudioStyle.indigoWash, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Activity & audit history").font(.subheadline.weight(.semibold)).foregroundStyle(StudioStyle.ink)
                                    Text("Decisions, comments, and version details").font(.caption).foregroundStyle(StudioStyle.secondaryInk)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(StudioStyle.tertiaryInk)
                            }
                            .padding(14)
                            .studioSurface(cornerRadius: 17)
                            .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(StudioStyle.separator.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .buttonStyle(StudioLinkStyle())
                        .accessibilityIdentifier("audit-history")
                    }
                }
                .padding(.horizontal, StudioStyle.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.automatic)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DemoRoleMenu()
            }
        }
    }
}

private struct ProjectMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(.title2, design: .serif, weight: .medium)).foregroundStyle(StudioStyle.ink)
            Text(label).font(.system(size: 8, weight: .bold)).tracking(0.8).foregroundStyle(StudioStyle.tertiaryInk)
        }
    }
}

private struct DeliverableVersionRow: View {
    let version: DemoVersion

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(StudioStyle.indigoWash)
                Image(systemName: "doc.text")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(StudioStyle.indigo)
            }
            .frame(width: 40, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text("Version \(version.number)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StudioStyle.ink)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if version.number == 1 {
                        Text("FIRST REVIEW")
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(StudioStyle.tertiaryInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Text(version.fileName)
                    .font(.caption)
                    .foregroundStyle(StudioStyle.secondaryInk)
                    .lineLimit(2)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    StatusPill(state: version.review)
                    Text(version.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(StudioStyle.tertiaryInk)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(StudioStyle.tertiaryInk)
                .padding(.leading, 2)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Version review and revision comparison

struct VersionDetailView: View {
    @EnvironmentObject private var store: DemoStore
    @StateObject private var model = VersionDetailModel()
    let versionID: UUID

    private var version: DemoVersion? { store.versions.first { $0.id == versionID } }
    private var previousVersion: DemoVersion? {
        guard let version else { return nil }
        return store.versions.first { $0.number == version.number - 1 }
    }

    var body: some View {
        ZStack {
            StudioStyle.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    if let version {
                        reviewContent(version)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle").font(.title2)
                            Text("Version unavailable").font(.headline)
                        }
                        .foregroundStyle(StudioStyle.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding(.horizontal, StudioStyle.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.automatic)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let version, version.review == .awaitingReview, store.role == .client {
                decisionBar(version: version)
            }
        }
        .sheet(isPresented: $model.isFeedbackPresented) {
            if let version {
                FeedbackSheet(versionNumber: version.number, comment: $model.comment) { feedback in
                    store.decide(version: version, approve: false, comment: feedback)
                    model.isFeedbackPresented = false
                } onCancel: {
                    model.isFeedbackPresented = false
                }
            }
        }
        .confirmationDialog(
            "Approve Version \(version?.number ?? 0)?",
            isPresented: $model.isApprovalConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Approve Version \(version?.number ?? 0)") {
                guard let version else { return }
                store.decide(version: version, approve: true, comment: "")
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This decision applies only to Version \(version?.number ?? 0). In this demo, it will be saved on this device only.")
        }
        .navigationTitle("Version \(version?.number ?? 0)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DemoRoleMenu()
            }
        }
    }

    @ViewBuilder
    private func reviewContent(_ version: DemoVersion) -> some View {
            VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .center) {
                    Text("VISUAL IDENTITY")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(StudioStyle.tertiaryInk)
                    Spacer()
                    StatusPill(state: version.review)
                }
                Text("Brand identity direction")
                    .font(.system(.title2, design: .serif, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(StudioStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Version \(version.number) · \(version.fileName)")
                    .font(.caption)
                    .foregroundStyle(StudioStyle.secondaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(.middle)
            }
            .padding(.top, 3)

            SyntheticPreview(versionNumber: version.number)

            HStack(spacing: 18) {
                MetadataItem(label: "PREPARED BY", value: DemoRole.name(for: version.author))
                Rectangle().fill(StudioStyle.separator).frame(width: 1, height: 35)
                MetadataItem(label: "SUBMITTED", value: version.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let previousVersion {
                VersionComparison(previous: previousVersion, current: version)
            }

            if let notice = store.notice {
                DemoNoticeBanner(message: notice) { withAnimation(.easeInOut(duration: 0.2)) { store.notice = nil } }
            }

            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(title: "Review notes")
                if let comment = version.comment, !comment.isEmpty {
                    HStack(alignment: .top, spacing: 11) {
                        RoundedRectangle(cornerRadius: 1).fill(StudioStyle.indigo).frame(width: 2)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(comment).font(.body).foregroundStyle(StudioStyle.ink).fixedSize(horizontal: false, vertical: true)
                            Text("\(DemoRole.name(for: version.review == .changesRequested ? DemoRole.client.subject : version.author)) · Version \(version.number)")
                                .font(.caption).foregroundStyle(StudioStyle.tertiaryInk)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioSurface(cornerRadius: 16)
                } else {
                    HStack(spacing: 9) {
                        Image(systemName: "text.bubble").foregroundStyle(StudioStyle.tertiaryInk)
                        Text("No comments on this version yet.").foregroundStyle(StudioStyle.secondaryInk)
                    }
                    .font(.footnote)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioSurface(cornerRadius: 16, color: StudioStyle.surfaceMuted.opacity(0.72))
                }
            }

            if store.role == .consultant {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(title: "Consultant workspace")
                    Button { withAnimation(.easeInOut(duration: 0.2)) { store.createRevision() } } label: {
                        Label("Create Version \(store.versions.map(\.number).max().map { $0 + 1 } ?? 2)", systemImage: "plus")
                    }
                    .buttonStyle(StudioButtonStyle(tone: .secondary))
                    Text("Creates a synthetic revision record on this device. It does not upload a file.")
                        .font(.caption)
                        .foregroundStyle(StudioStyle.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 3)
            }

            NavigationLink { AuditView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("View activity & audit history")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(StudioStyle.indigo)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .buttonStyle(StudioLinkStyle())
        }
    }

    @ViewBuilder
    private func decisionBar(version: DemoVersion) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Button { model.isFeedbackPresented = true } label: {
                Label("Request changes", systemImage: "arrow.uturn.backward")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .buttonStyle(StudioButtonStyle(tone: .secondary))
            .accessibilityIdentifier("request-changes")
            Button { model.isApprovalConfirmationPresented = true } label: {
                Label("Approve", systemImage: "checkmark")
                    .lineLimit(1)
            }
            .buttonStyle(StudioButtonStyle(tone: .primary))
            .accessibilityIdentifier("approve-version")
        }
        .padding(.horizontal, StudioStyle.pageInset)
        .padding(.top, 9)
        .padding(.bottom, 9)
        .background(StudioStyle.paper.opacity(0.97))
        .overlay(alignment: .top) { Rectangle().fill(StudioStyle.separator.opacity(0.75)).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Actions apply to Version \(version.number) only")
    }
}

private struct SyntheticPreview: View {
    let versionNumber: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            StudioStyle.surfaceMuted
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("NORTHSTAR  /  IDENTITY")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.2)
                    Spacer()
                    Text("0\(versionNumber)")
                        .font(.system(.caption, design: .serif, weight: .medium))
                }
                .foregroundStyle(StudioStyle.secondaryInk)
                Spacer(minLength: 12)
                HStack(alignment: .bottom, spacing: 5) {
                    Text("N")
                        .font(.system(size: 82, weight: .regular, design: .serif))
                        .tracking(-5)
                        .foregroundStyle(StudioStyle.ink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NORTHSTAR")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(2.1)
                        Text("A CLEARER POINT OF VIEW")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(1.2)
                    }
                    .foregroundStyle(StudioStyle.ink)
                    .padding(.bottom, 17)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 9)
                HStack {
                    Text("SYNTHETIC PREVIEW · NO FILE ATTACHED")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: "sparkle")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(StudioStyle.tertiaryInk)
            }
            .padding(19)
        }
        .aspectRatio(1.72, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Synthetic design preview for version \(versionNumber). No file is attached.")
    }
}

private struct MetadataItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).tracking(0.95).foregroundStyle(StudioStyle.tertiaryInk)
            Text(value).font(.caption.weight(.medium)).foregroundStyle(StudioStyle.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct VersionComparison: View {
    let previous: DemoVersion
    let current: DemoVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Eyebrow(title: "Version history", trailing: "Decisions stay version-specific")
            HStack(spacing: 9) {
                versionCell(previous, heading: "PREVIOUS")
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(StudioStyle.tertiaryInk)
                    .padding(.horizontal, 1)
                versionCell(current, heading: "UNDER REVIEW", emphasized: true)
            }
        }
    }

    private func versionCell(_ version: DemoVersion, heading: String, emphasized: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(heading)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(StudioStyle.tertiaryInk)
            Text("Version \(version.number)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StudioStyle.ink)
            StatusPill(state: version.review)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(12)
        .background(emphasized ? StudioStyle.indigoWash.opacity(0.65) : StudioStyle.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(emphasized ? StudioStyle.indigo.opacity(0.22) : StudioStyle.separator.opacity(0.55), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Feedback and approval actions

private struct FeedbackSheet: View {
    let versionNumber: Int
    @Binding var comment: String
    let onSubmit: (String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var trimmedComment: String { comment.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { !trimmedComment.isEmpty && trimmedComment.count <= 4_000 }

    var body: some View {
        ZStack {
            StudioStyle.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("YOUR FEEDBACK")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(StudioStyle.tertiaryInk)
                        Spacer()
                        Button(action: close) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(StudioStyle.secondaryInk)
                                .frame(width: 44, height: 44)
                                .background(StudioStyle.surfaceMuted, in: Circle())
                        }
                        .buttonStyle(StudioLinkStyle())
                        .accessibilityLabel("Close feedback")
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Request changes")
                            .font(.system(.title2, design: .serif, weight: .medium))
                            .tracking(-0.3)
                            .foregroundStyle(StudioStyle.ink)
                        Text("Your note will be attached to Version \(versionNumber) only.")
                            .font(.subheadline)
                            .foregroundStyle(StudioStyle.secondaryInk)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("WHAT SHOULD CHANGE?")
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(StudioStyle.tertiaryInk)
                        TextField("Be specific and constructive…", text: $comment, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(StudioStyle.ink)
                            .lineLimit(4...7)
                            .padding(15)
                            .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(StudioStyle.separator.opacity(0.75), lineWidth: 1))
                            .accessibilityLabel("Feedback for Version \(versionNumber)")
                            .accessibilityIdentifier("feedback-version-\(versionNumber)")
                        HStack {
                            Text(trimmedComment.isEmpty ? "A comment is required to request changes." : "Clear feedback helps the next revision.")
                                .font(.caption)
                                .foregroundStyle(StudioStyle.secondaryInk)
                            Spacer()
                            Text("\(comment.count) / 4,000")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(comment.count > 4_000 ? StudioStyle.rust : StudioStyle.tertiaryInk)
                        }
                    }
                    HStack(spacing: 9) {
                        Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        Text("Synthetic demo · this action stays on this device.")
                    }
                    .font(.caption)
                    .foregroundStyle(StudioStyle.tertiaryInk)
                }
                .padding(.horizontal, StudioStyle.pageInset)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.automatic)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                onSubmit(trimmedComment)
            } label: {
                Label("Send request for Version \(versionNumber)", systemImage: "arrow.up.right")
            }
            .buttonStyle(StudioButtonStyle(tone: .primary))
            .accessibilityIdentifier("submit-feedback")
            .disabled(!isValid)
            .accessibilityHint(isValid ? "Saves this feedback to the local demo record." : "Enter a comment of 1 to 4,000 characters to enable this action.")
            .padding(.horizontal, StudioStyle.pageInset)
            .padding(.top, 12)
            .padding(.bottom, 9)
            .background(StudioStyle.paper.opacity(0.98))
            .overlay(alignment: .top) { Rectangle().fill(StudioStyle.separator.opacity(0.75)).frame(height: 1) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }

    private func close() {
        onCancel()
        dismiss()
    }
}

// MARK: - Activity and audit history

struct AuditView: View {
    @EnvironmentObject private var store: DemoStore

    var body: some View {
        ZStack {
            StudioStyle.paper.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Activity")
                            .font(.system(.title2, design: .serif, weight: .medium))
                            .tracking(-0.3)
                            .foregroundStyle(StudioStyle.ink)
                        Text("A local record of decisions on each version.")
                            .font(.subheadline)
                            .foregroundStyle(StudioStyle.secondaryInk)
                    }
                    if let notice = store.notice {
                        DemoNoticeBanner(message: notice) { withAnimation(.easeInOut(duration: 0.2)) { store.notice = nil } }
                    }
                    if store.audit.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 19))
                                .foregroundStyle(StudioStyle.indigo)
                                .frame(width: 44, height: 44)
                                .background(StudioStyle.indigoWash, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text("The review begins here")
                                .font(.system(.title3, design: .serif, weight: .medium))
                                .foregroundStyle(StudioStyle.ink)
                            Text("When the client requests changes or approves a version, the action and its exact version will appear in this local activity record.")
                                .font(.footnote)
                                .foregroundStyle(StudioStyle.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(19)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .studioSurface(cornerRadius: 19)
                        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(StudioStyle.separator.opacity(0.65), lineWidth: 1))
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.audit.enumerated()), id: \.element.id) { index, event in
                                AuditTimelineRow(event: event, isLast: index == store.audit.count - 1)
                            }
                        }
                        .padding(.horizontal, 17)
                        .padding(.vertical, 8)
                        .studioSurface(cornerRadius: 19)
                        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(StudioStyle.separator.opacity(0.65), lineWidth: 1))
                    }
                    Text("LOCAL DEMO · Activity is stored in memory and is not a server audit record.")
                        .font(.caption)
                        .foregroundStyle(StudioStyle.tertiaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, StudioStyle.pageInset)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.automatic)
        }
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                DemoRoleMenu()
            }
        }
    }
}

private struct AuditTimelineRow: View {
    let event: DemoAudit
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 0) {
                Circle()
                    .fill(event.action == "Approved" ? StudioStyle.green : StudioStyle.indigo)
                    .frame(width: 9, height: 9)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle().fill(StudioStyle.separator).frame(width: 1).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(event.action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StudioStyle.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 3)
                    Text("V\(event.versionNumber)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(StudioStyle.indigo)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(StudioStyle.indigoWash, in: Capsule())
                }
                Text(DemoRole.name(for: event.actor))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(StudioStyle.secondaryInk)
                if let comment = event.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.footnote)
                        .foregroundStyle(StudioStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(StudioStyle.tertiaryInk)
                    .padding(.top, 1)
            }
            .padding(.bottom, isLast ? 13 : 23)
        }
        .padding(.top, 13)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.action), Version \(event.versionNumber), by \(DemoRole.name(for: event.actor)), \(event.date.formatted(date: .abbreviated, time: .shortened))\(event.comment.map { ". \($0)" } ?? "")")
    }
}
