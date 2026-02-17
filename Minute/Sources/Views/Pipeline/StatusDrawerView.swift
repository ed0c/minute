import SwiftUI

struct StatusDrawerModel {
    let title: String
    let detail: String
    let progress: Double?
    let showsActivity: Bool
    let isError: Bool
    let actionTitle: String?
    let action: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?
    let onClose: (() -> Void)?

    init(
        title: String,
        detail: String,
        progress: Double?,
        showsActivity: Bool,
        isError: Bool,
        actionTitle: String?,
        action: (() -> Void)?,
        secondaryActionTitle: String?,
        secondaryAction: (() -> Void)?,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.progress = progress
        self.showsActivity = showsActivity
        self.isError = isError
        self.actionTitle = actionTitle
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryAction = secondaryAction
        self.onClose = onClose
    }
}

struct StatusDrawerView: View {
    let model: StatusDrawerModel
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.isError ? Color.red.opacity(0.9) : Color.minuteTextPrimary)

                Spacer(minLength: 0)

                if let onClose = model.onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.minuteTextSecondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Close status drawer"))
                }
            }

            Text(model.detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.minuteTextSecondary)
                .lineLimit(isCompact ? 1 : nil)
                .truncationMode(.tail)

            if let progress = model.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            } else if model.showsActivity {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            if let actionTitle = model.actionTitle, let action = model.action {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)

                    if let secondaryTitle = model.secondaryActionTitle,
                       let secondaryAction = model.secondaryAction {
                        Button(secondaryTitle) {
                            secondaryAction()
                        }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(Color.minuteTextPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.minuteOutline, lineWidth: 1)
                        )
                    }

                    Button(actionTitle) {
                        action()
                    }
                    .minuteStandardButtonStyle()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isCompact ? 10 : 12)
        .minuteGlassPanel(
            cornerRadius: 16,
            fill: Color.minuteSurfaceStrong,
            border: model.isError ? Color.red.opacity(0.6) : Color.minuteOutline,
            shadowOpacity: 0.2
        )
    }
}
