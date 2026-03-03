import SwiftUI

/// GDPR consent screen shown on first launch.
/// Users must actively consent before any data is stored.
struct ConsentView: View {
    @EnvironmentObject var gdprManager: GDPRManager
    @State private var showPrivacyDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 20)

                    Image(systemName: "tram.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text("Welcome to SiriMetra")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your privacy-first Metra companion")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    // Privacy summary card
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Your Data, Your Device", systemImage: "lock.shield.fill")
                            .font(.headline)

                        privacyPoint(
                            icon: "iphone",
                            text: "All data stays on your device"
                        )
                        privacyPoint(
                            icon: "xmark.shield",
                            text: "No tracking or analytics"
                        )
                        privacyPoint(
                            icon: "server.rack",
                            text: "No data sent to our servers"
                        )
                        privacyPoint(
                            icon: "network",
                            text: "Only connects to Metra's public schedule API"
                        )
                        privacyPoint(
                            icon: "trash",
                            text: "Delete all your data anytime"
                        )
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // What we store
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What we store on your device:")
                            .font(.headline)

                        Text("• Your chosen home and work stations")
                        Text("• Notification preferences")
                        Text("• Preferred Metra lines")
                        Text("• Your consent record")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("View Full Privacy Policy") {
                        showPrivacyDetails = true
                    }
                    .font(.footnote)

                    // Consent buttons
                    VStack(spacing: 12) {
                        Button {
                            gdprManager.grantConsent()
                        } label: {
                            Text("I Agree — Continue")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            gdprManager.withdrawConsent()
                        } label: {
                            Text("No Thanks")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(.secondary)
                        }

                        Text("You can change your mind at any time in Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
            .sheet(isPresented: $showPrivacyDetails) {
                PrivacyPolicyView()
            }
        }
    }

    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
}
