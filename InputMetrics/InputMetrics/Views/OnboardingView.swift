import SwiftUI

struct OnboardingView: View {
    @State private var currentStep = 0
    var onComplete: () -> Void

    private let steps: [(icon: String, title: String, description: String)] = [
        ("cursorarrow.motionlines", "Track Your Input",
         "InputMetrics runs in your menu bar and tracks mouse movements, clicks, keyboard usage, and scroll activity."),
        ("lock.shield", "Privacy First",
         "All data stays on your device. No data is sent anywhere. InputMetrics needs Accessibility permission to track input events."),
        ("chart.bar.xaxis", "View Your Stats",
         "Click the menu bar icon to see today's activity. Open the dashboard for detailed charts and heatmaps."),
        ("gearshape", "Customize",
         "Configure distance units, data retention, and export your data from Settings.")
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: steps[currentStep].icon)
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text(steps[currentStep].title)
                .font(.title.bold())

            Text(steps[currentStep].description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .frame(width: 450, height: 400)
    }
}
