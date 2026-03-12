import SwiftUI

struct MiniKeyboardHeatmap: View {
    let entries: [KeyboardEntry]

    private var keyCountMap: [Int: Int] {
        var map: [Int: Int] = [:]
        for entry in entries {
            map[entry.keyCode, default: 0] += entry.count
        }
        return map
    }

    private var maxCount: Int {
        keyCountMap.values.max() ?? 1
    }

    private var keyboardLayout: [[(keyCode: Int, label: String, width: CGFloat)]] {
        KeyCodeMapping.qwertzLayoutWithCodes
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<keyboardLayout.count, id: \.self) { rowIndex in
                HStack(spacing: 2) {
                    ForEach(0..<keyboardLayout[rowIndex].count, id: \.self) { keyIndex in
                        let key = keyboardLayout[rowIndex][keyIndex]
                        let count = keyCountMap[key.keyCode] ?? 0
                        let intensity = Double(count) / Double(maxCount)

                        KeyCapView(
                            label: key.label,
                            count: count,
                            intensity: intensity,
                            width: key.width
                        )
                    }
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.05))
        .cornerRadius(8)
    }
}

struct KeyCapView: View {
    let label: String
    let count: Int
    let intensity: Double
    let width: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 6))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 28 * width, height: 28)
        .background(HeatmapColor.forKeyboardIntensity(intensity))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

}
