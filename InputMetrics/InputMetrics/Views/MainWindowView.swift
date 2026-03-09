import SwiftUI

struct MainWindowView: View {
    @State private var selectedTab: MetricTab = .mouse

    var body: some View {
        VStack(spacing: 0) {
            // Header with tab switcher
            HStack {
                Picker("View", selection: $selectedTab) {
                    Text("Mouse").tag(MetricTab.mouse)
                    Text("Keyboard").tag(MetricTab.keyboard)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                switch selectedTab {
                case .mouse:
                    MouseStatsView()
                case .keyboard:
                    KeyboardStatsView()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    MainWindowView()
}
