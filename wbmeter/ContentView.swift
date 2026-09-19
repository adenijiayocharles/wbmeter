import AVFoundation
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var camera = CameraService()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var activeNotice: Notice?

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            ZStack {
                Color.black

                if camera.authorization == .authorized {
                    CameraPreview(session: camera.session)

                    VStack(spacing: 0) {
                        MeasurementTarget()
                            .frame(width: 240, height: 240)

                        Text("Place a grey card inside the frame")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .padding(.top, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Label(camera.statusText, systemImage: camera.statusSymbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(camera.isRunning ? Color.green : Color.secondary)
                        .accessibilityElement(children: .combine)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 14)
                        .padding(.leading, 16)
                } else {
                    permissionPrompt
                        .padding(32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            measureControl
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert(
            activeNotice?.title ?? "",
            isPresented: Binding(
                get: { activeNotice != nil },
                set: { if !$0 { activeNotice = nil } }
            ),
            presenting: activeNotice
        ) { _ in
            Button("OK", role: .cancel) { activeNotice = nil }
        } message: { notice in
            Text(notice.message)
        }
        .task { await camera.requestAccessAndStart() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await camera.requestAccessAndStart() }
            case .background:
                camera.stop()
            default:
                break
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: 44, height: 44)

            Spacer()

            Text("WB Meter")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                activeNotice = .settings
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var permissionPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: camera.promptSymbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.white.opacity(0.85))
                .accessibilityHidden(true)
            Text(camera.promptTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(camera.promptMessage)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            if camera.authorization == .denied {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(.black)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: 360)
    }

    private var measureControl: some View {
        Button {
            activeNotice = .measurement
        } label: {
            ZStack {
                Circle()
                    .stroke(.white.opacity(camera.isRunning ? 1 : 0.45), lineWidth: 3.5)
                    .frame(width: 74, height: 74)
                Circle()
                    .fill(.white.opacity(camera.isRunning ? 1 : 0.45))
                    .frame(width: 60, height: 60)
            }
            .frame(width: 80, height: 80)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!camera.isRunning)
        .accessibilityLabel("Measure")
        .accessibilityHint("Measurement capture is not available in this milestone.")
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 24)
        .background(Color.black)
    }

    private enum Notice {
        case settings
        case measurement

        var title: String {
            switch self {
            case .settings: "Settings"
            case .measurement: "Measurement capture isn’t available yet"
            }
        }

        var message: String {
            switch self {
            case .settings:
                "Additional camera settings will be available in a later milestone."
            case .measurement:
                "The camera preview is ready. Capture and measurement will be added in a later milestone."
            }
        }
    }
}

private struct MeasurementTarget: View {
    private let cornerLength: CGFloat = 26
    private let lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(.white.opacity(0.38), lineWidth: 1)
            corners
        }
        .accessibilityLabel("Central grey-card measurement area")
        .allowsHitTesting(false)
    }

    private var corners: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            Path { path in
                path.move(to: CGPoint(x: 0, y: cornerLength))
                path.addLine(to: .zero)
                path.addLine(to: CGPoint(x: cornerLength, y: 0))

                path.move(to: CGPoint(x: w - cornerLength, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: cornerLength))

                path.move(to: CGPoint(x: w, y: h - cornerLength))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w - cornerLength, y: h))

                path.move(to: CGPoint(x: cornerLength, y: h))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h - cornerLength))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square))
        }
    }
}

#Preview {
    ContentView()
}
