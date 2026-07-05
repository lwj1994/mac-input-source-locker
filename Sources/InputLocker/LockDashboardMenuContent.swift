import AppKit
import SwiftUI

struct LockDashboardMenuContent: View {
    static let width: CGFloat = 372

    let isLockEnabled: Bool
    let targetName: String
    let appLockName: String
    let frontmostApplicationName: String?

    private var statusColor: Color {
        isLockEnabled ? .green : .secondary
    }

    private var globalLockText: String {
        isLockEnabled ? targetName : L10n.dashboardNotEnabled
    }

    private var currentAppText: String {
        frontmostApplicationName ?? L10n.dashboardUnavailable
    }

    private var statusIconImage: NSImage? {
        AppResourceBundle.current.url(forResource: "InputLockerStatusIcon", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                statusIcon

                Text("InputLocker")
                    .font(.system(size: 13, weight: .semibold))

                Spacer(minLength: 12)

                Text(isLockEnabled ? L10n.dashboardStatusLocked : L10n.dashboardStatusPaused)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                row(title: L10n.dashboardGlobalLock, value: globalLockText)
                row(title: L10n.dashboardAppLock, value: appLockName)
                row(title: L10n.dashboardCurrentApp, value: currentAppText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(width: Self.width, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(statusColor)

            if let statusIconImage {
                Image(nsImage: statusIconImage)
                    .resizable()
                    .renderingMode(.original)
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "keyboard")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 23, height: 23)
    }

    private func row(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .frame(width: 72, alignment: .leading)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}
