import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: CaptureTimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Next Expected Capture")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 16)

            Text(viewModel.isPaused ? "PAUSED" : viewModel.formattedRemaining)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(viewModel.isPaused ? .orange : .primary)

            HStack {
                Text("Rolling Average:")
                    .foregroundColor(.secondary)
                Text(viewModel.formattedAverage)
                    .fontWeight(.semibold)
            }
            .font(.caption)

            Divider()

            Text("Recent Captures")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            List(viewModel.history) { event in
                HStack {
                    VStack(alignment: .leading) {
                        Text(event.type.uppercased())
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(4)
                        Text(event.bundleID)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(event.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit())
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 200)
            
            HStack(spacing: 20) {
                Button(action: {
                    viewModel.togglePause()
                }) {
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .frame(width: 80)
                }
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .frame(width: 80)
            }
            .padding(.bottom, 16)
        }
        .frame(width: 320, height: 400)
    }
}
