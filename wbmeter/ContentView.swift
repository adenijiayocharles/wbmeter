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

            GeometryReader { geometry in
                let roiWidth = geometry.size.width * 0.20
                let roiHeight = geometry.size.height * 0.20

                ZStack {
                    Color.black

                    if camera.authorization == .authorized {
                        CameraPreview(session: camera.session)

                        MeasurementTarget()
                            .frame(width: roiWidth, height: roiHeight)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                        Text("Place a grey card inside the frame")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .position(
                                x: geometry.size.width / 2,
                                y: geometry.size.height / 2 + roiHeight / 2 + 30
                            )

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
        .task {
            await camera.requestAccessAndStart()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--capture-raw-on-launch") {
                await camera.captureMeasurement()
            }
            #endif
        }
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
        VStack(spacing: 12) {
            if let diagnostics = camera.captureDiagnostics {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(diagnostics.debugLines, id: \.self) { line in
                        Text(line)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 18)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("RAW sensor capture details")
            } else if let message = camera.captureMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(camera.isCapturing ? Color.secondary : Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text(camera.captureCapability)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            Button {
                Task { await camera.captureMeasurement() }
            } label: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(camera.isRunning && !camera.isCapturing ? 1 : 0.45), lineWidth: 3.5)
                        .frame(width: 74, height: 74)
                    Circle()
                        .fill(.white.opacity(camera.isRunning && !camera.isCapturing ? 1 : 0.45))
                        .frame(width: 60, height: 60)
                }
                .frame(width: 80, height: 80)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(!camera.isRunning || camera.isCapturing)
            .accessibilityLabel(camera.isCapturing ? "Capturing RAW sensor data" : "Measure")
            .accessibilityHint("Captures a RAW Bayer sample and reports linear channel levels for the central region.")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Color.black)
    }

    private enum Notice {
        case settings
        case measurement

        var title: String {
            "Settings"
        }

        var message: String {
            "Additional camera settings will be available in a later milestone."
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
