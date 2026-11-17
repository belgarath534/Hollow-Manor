import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var playing = false
    /// Changes for every new game, so "Play again" starts fresh.
    @State private var gameID = UUID()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 8) {
                    Text("Hollow Manor")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("You're invited.")
                        .font(.system(.title3, design: .serif).italic())
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 14) {
                    Button {
                        gameID = UUID()
                        playing = true
                    } label: {
                        Text("Play").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.55, green: 0.1, blue: 0.12))

                    NavigationLink {
                        HowToPlayView()
                    } label: {
                        Text("How to Play").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Text("Settings").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        CreditsView()
                    } label: {
                        Text("Credits").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: 420)
                Text("Headphones recommended.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            }
            .background(Color.black.ignoresSafeArea())
        }
        .onAppear { MusicPlayer.shared.play(.menu) }
        .onChange(of: playing) { _, isPlaying in
            if !isPlaying { MusicPlayer.shared.play(.menu) }
        }
        .fullScreenCover(isPresented: $playing) {
            GameScreen(settings: settings,
                       onPlayAgain: { gameID = UUID() },
                       onQuit: { playing = false })
                .id(gameID)
        }
    }
}
