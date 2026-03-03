import SwiftUI

/// In-app privacy policy viewer.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section(
                        title: "Privacy Policy",
                        content: """
                        Last updated: March 2026

                        SiriMetra ("the App") is committed to protecting your privacy. \
                        This policy explains what data we collect, how we use it, and your rights.
                        """
                    )

                    section(
                        title: "1. Data We Collect",
                        content: """
                        The App stores the following data locally on your device:
                        • Your selected home and work Metra stations
                        • Notification preferences (on/off, delay threshold)
                        • Preferred Metra lines
                        • Your GDPR consent record (date and status)

                        We do NOT collect:
                        • Your location
                        • Device identifiers
                        • Usage analytics or telemetry
                        • Any personally identifiable information
                        """
                    )

                    section(
                        title: "2. How We Use Your Data",
                        content: """
                        Your station preferences are used solely to:
                        • Answer "next train" queries via Siri
                        • Display relevant schedule information
                        • Send local notifications about delays (if enabled)

                        This data never leaves your device.
                        """
                    )

                    section(
                        title: "3. Data Sharing",
                        content: """
                        We do NOT share your data with anyone. Period.

                        The only network requests the App makes are to Metra's \
                        public GTFS API to fetch train schedules and service alerts. \
                        No user data is included in these requests.
                        """
                    )

                    section(
                        title: "4. Data Storage & Security",
                        content: """
                        All data is stored in your device's local storage (UserDefaults). \
                        It is protected by your device's built-in security (passcode, Face ID, etc.).

                        We do not operate any servers. There is no cloud sync, \
                        no remote database, and no backend infrastructure.
                        """
                    )

                    section(
                        title: "5. Your Rights (GDPR)",
                        content: """
                        Under the General Data Protection Regulation (GDPR), you have the right to:

                        • Access: View all data stored about you (Privacy Dashboard)
                        • Portability: Export your data as a JSON file
                        • Erasure: Delete all your data at any time
                        • Withdraw Consent: Revoke consent and delete all data
                        • Rectification: Modify your preferences at any time in Settings

                        You can exercise all these rights from the Privacy Dashboard \
                        in Settings, at any time, without contacting us.
                        """
                    )

                    section(
                        title: "6. Children's Privacy",
                        content: """
                        The App does not knowingly collect any data from children. \
                        Since all data is stored locally and we collect no personal \
                        information, the App is safe for users of all ages.
                        """
                    )

                    section(
                        title: "7. Third-Party Services",
                        content: """
                        The App uses no third-party SDKs, analytics tools, \
                        advertising frameworks, or tracking services.

                        The only external service accessed is Metra's public \
                        GTFS (General Transit Feed Specification) API for schedule data.
                        """
                    )

                    section(
                        title: "8. Changes to This Policy",
                        content: """
                        Any changes to this privacy policy will be communicated \
                        through an app update. The updated policy will be displayed \
                        in the App before you are asked to re-consent.
                        """
                    )

                    section(
                        title: "9. Contact",
                        content: """
                        If you have questions about this privacy policy, please \
                        contact us through the App Store listing.
                        """
                    )
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
