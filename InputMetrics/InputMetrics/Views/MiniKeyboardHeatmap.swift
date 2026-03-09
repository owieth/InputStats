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

    // QWERTZ layout with key codes
    private let keyboardLayout: [[(keyCode: Int, label: String, width: CGFloat)]] = [
        // Number row
        [(50, "^", 1), (18, "1", 1), (19, "2", 1), (20, "3", 1), (21, "4", 1), (23, "5", 1), (22, "6", 1), (26, "7", 1), (28, "8", 1), (25, "9", 1), (29, "0", 1), (27, "ß", 1), (24, "´", 1)],
        // QWERTZ row
        [(12, "Q", 1), (13, "W", 1), (14, "E", 1), (15, "R", 1), (17, "T", 1), (16, "Z", 1), (32, "U", 1), (34, "I", 1), (31, "O", 1), (35, "P", 1), (33, "Ü", 1), (30, "+", 1)],
        // ASDF row
        [(0, "A", 1), (1, "S", 1), (2, "D", 1), (3, "F", 1), (5, "G", 1), (4, "H", 1), (38, "J", 1), (40, "K", 1), (37, "L", 1), (41, "Ö", 1), (39, "Ä", 1), (42, "#", 1)],
        // YXCV row
        [(6, "Y", 1), (7, "X", 1), (8, "C", 1), (9, "V", 1), (11, "B", 1), (45, "N", 1), (46, "M", 1), (43, ",", 1), (47, ".", 1), (44, "-", 1)],
        // Space row
        [(49, "Space", 6)]
    ]

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
        .background(colorForIntensity(intensity))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func colorForIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color.gray.opacity(0.15)
        } else if intensity < 0.2 {
            return Color.purple.opacity(0.25)
        } else if intensity < 0.4 {
            return Color.purple.opacity(0.45)
        } else if intensity < 0.6 {
            return Color.purple.opacity(0.65)
        } else if intensity < 0.8 {
            return Color.purple.opacity(0.8)
        } else {
            return Color.purple
        }
    }
}
