import ManorCore
import SwiftUI

struct GameScreen: View {
    @StateObject private var controller: GameController
    @ObservedObject private var settings: AppSettings
    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    init(settings: AppSettings, onPlayAgain: @escaping () -> Void, onQuit: @escaping () -> Void) {
        _controller = StateObject(wrappedValue: GameController(settings: settings))
        self.settings = settings
        self.onPlayAgain = onPlayAgain
        self.onQuit = onQuit
    }

    private var isActive: Bool { controller.phase == .playing || controller.phase == .intro }

    var body: some View {
        ZStack {
            GameSurface(controller: controller, isActive: isActive)
                .ignoresSafeArea()

            if settings.captions && !controller.caption.isEmpty && isActive {
                VStack {
                    Spacer()
                    Text(controller.caption)
                        .font(.callout.weight(.medium))
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .frame(maxWidth: 600)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                        .accessibilityHidden(true) // already spoken
                }
                .allowsHitTesting(false)
            }

            if controller.phase == .intro {
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip intro") { controller.handle(.interact) }
                            .buttonStyle(.bordered)
                            .padding()
                    }
                    Spacer()
                }
            }

            if controller.phase == .paused {
                PauseMenu(controller: controller, onQuit: quit)
            }

            if case let .ended(outcome) = controller.phase {
                EndView(outcome: outcome, onPlayAgain: {
                    controller.stop()
                    onPlayAgain()
                }, onQuit: quit)
            }
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private func quit() {
        controller.stop()
        onQuit()
    }
}

private struct PauseMenu: View {
    @ObservedObject var controller: GameController
    let onQuit: () -> Void
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Paused").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Button("Resume") { controller.resume() }
                .buttonStyle(.borderedProminent)
            Button("How to Play") { showHelp = true }
                .buttonStyle(.bordered)
            Button("Quit to Menu", role: .destructive, action: onQuit)
                .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityAction(.escape) { controller.resume() }
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                HowToPlayView()
                    .toolbar { Button("Done") { showHelp = false } }
            }
        }
    }
}

private struct EndView: View {
    let outcome: Outcome
    let onPlayAgain: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text(outcome == .escaped ? "You escaped" : "Caught")
                .font(.system(.largeTitle, design: .serif).bold())
                .foregroundStyle(outcome == .escaped ? Color.white : Color.red)
                .accessibilityAddTraits(.isHeader)
            Text(outcome == .escaped
                 ? "You made it out of Hollow Manor. But your friend is still in there."
                 : "The Hunter found you. The Host is setting another place at the table.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Play Again", action: onPlayAgain)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.55, green: 0.1, blue: 0.12))
            Button("Main Menu", action: onQuit)
                .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(32)
        .frame(maxWidth: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}
