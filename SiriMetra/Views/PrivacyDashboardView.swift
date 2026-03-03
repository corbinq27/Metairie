import SwiftUI

/// GDPR Privacy Dashboard — allows users to view, export, and delete their data.
struct PrivacyDashboardView: View {
    @EnvironmentObject var gdprManager: GDPRManager
    @EnvironmentObject var preferencesStore: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Data Categories
                Section {
                    ForEach(gdprManager.dataCategories()) { category in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(category.name)
                                    .font(.headline)
                                Spacer()
                                if !category.shared {
                                    Label("Local only", systemImage: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                            Text(category.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Purpose: \(category.purpose)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("What We Store")
                } footer: {
                    Text("All data is stored exclusively on your device. Nothing is sent to any server.")
                }

                // MARK: - Consent Status
                Section("Consent") {
                    HStack {
                        Text("Status")
                        Spacer()
                        switch gdprManager.consentStatus {
                        case .granted:
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .denied:
                            Label("Denied", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        case .notDetermined:
                            Label("Not set", systemImage: "questionmark.circle")
                                .foregroundStyle(.orange)
                        }
                    }

                    if let date = preferencesStore.preferences.gdprConsentDate {
                        HStack {
                            Text("Consent Date")
                            Spacer()
                            Text(date, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Your Rights (GDPR Articles 15-20)
                Section {
                    // Article 15 — Right of access
                    Button {
                        exportURL = gdprManager.portableDataURL()
                        showExportSheet = exportURL != nil
                    } label: {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }

                    // Article 17 — Right to erasure
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All My Data", systemImage: "trash")
                    }

                    // Withdraw consent
                    if gdprManager.consentStatus == .granted {
                        Button(role: .destructive) {
                            gdprManager.withdrawConsent()
                            dismiss()
                        } label: {
                            Label("Withdraw Consent", systemImage: "hand.raised.slash")
                        }
                    }
                } header: {
                    Text("Your Rights")
                } footer: {
                    Text("""
                    Under GDPR, you have the right to access, export, and delete your personal data at any time. \
                    Withdrawing consent will delete all stored data and reset the app.
                    """)
                }

                // MARK: - Privacy Policy
                Section("Privacy Policy") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("View Full Privacy Policy", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Privacy Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    gdprManager.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all your preferences and reset the app. This action cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
        }
    }
}

/// Wrapper for UIActivityViewController to share the exported data file.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
