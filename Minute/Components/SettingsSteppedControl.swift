import SwiftUI

struct SettingsSteppedControl: View {
    let stepLabels: [String]
    @Binding var selectedIndex: Int

    private let trackHeight: CGFloat = 8
    private let knobSize: CGFloat = 18
    private let controlHeight: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                let metrics = StepMetrics(width: proxy.size.width, stepCount: stepLabels.count)

                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: metrics.trackWidth, height: trackHeight)
                            .offset(x: metrics.trackStartX)

                        Capsule()
                            .fill(Color.accentColor.opacity(0.45))
                            .frame(width: metrics.fillWidth(for: selectedIndex), height: trackHeight)
                            .offset(x: metrics.trackStartX)

                        ForEach(stepLabels.indices, id: \.self) { index in
                            Circle()
                                .fill(index <= selectedIndex ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.25))
                                .frame(width: 4, height: 4)
                                .position(x: metrics.centerX(for: index), y: controlHeight / 2)
                        }

                        Circle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: knobSize, height: knobSize)
                            .shadow(color: .black.opacity(0.22), radius: 4, y: 1)
                            .position(x: metrics.centerX(for: selectedIndex), y: controlHeight / 2)

                        HStack(spacing: 0) {
                            ForEach(stepLabels.indices, id: \.self) { index in
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedIndex = index
                                    }
                            }
                        }
                    }
                    .frame(height: controlHeight)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                selectedIndex = metrics.nearestIndex(for: value.location.x)
                            }
                    )

                    HStack(spacing: 0) {
                        ForEach(stepLabels.indices, id: \.self) { index in
                            Text(stepLabels[index])
                                .font(.caption)
                                .foregroundStyle(index == selectedIndex ? .primary : .secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }
            }
            .frame(height: controlHeight + 28)
        }
    }
}

private struct StepMetrics {
    let width: CGFloat
    let stepCount: Int

    private var safeStepCount: Int {
        max(stepCount, 1)
    }

    private var columnWidth: CGFloat {
        width / CGFloat(safeStepCount)
    }

    var trackStartX: CGFloat {
        centerX(for: 0)
    }

    var trackEndX: CGFloat {
        centerX(for: safeStepCount - 1)
    }

    var trackWidth: CGFloat {
        max(trackEndX - trackStartX, 0)
    }

    func centerX(for index: Int) -> CGFloat {
        let clamped = max(0, min(index, safeStepCount - 1))
        return columnWidth * (CGFloat(clamped) + 0.5)
    }

    func fillWidth(for index: Int) -> CGFloat {
        max(centerX(for: index) - trackStartX, 0)
    }

    func nearestIndex(for x: CGFloat) -> Int {
        guard safeStepCount > 1 else { return 0 }
        let raw = Int(round((x / columnWidth) - 0.5))
        return max(0, min(raw, safeStepCount - 1))
    }
}
