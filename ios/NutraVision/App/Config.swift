import Foundation

/// Supabase connection values, set per machine in `ios/Config.local.xcconfig` (gitignored) and
/// copied into Info.plist at build time. The anon / publishable key is safe to ship in the app:
/// row-level security is what protects the data.
enum Config {
    private static let placeholderHost = "YOUR-PROJECT.supabase.co"

    private static func info(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// Host only, e.g. `abcdefghijkl.supabase.co`. Tolerates a pasted `https://` prefix or trailing slash.
    private static var host: String {
        var value = info("SupabaseHost")
        for prefix in ["https://", "http://"] where value.hasPrefix(prefix) { value.removeFirst(prefix.count) }
        while value.hasSuffix("/") { value.removeLast() }
        return value.isEmpty || value.contains("$(") ? placeholderHost : value
    }

    static let supabaseURL = URL(string: "https://\(host)") ?? URL(string: "https://\(placeholderHost)")!
    static let supabaseAnonKey: String = {
        let key = info("SupabaseAnonKey")
        return key.isEmpty || key.contains("$(") ? "YOUR-ANON-KEY" : key
    }()

    /// False until Config.local.xcconfig points the app at a real Supabase project.
    static var isConfigured: Bool { host != placeholderHost && supabaseAnonKey != "YOUR-ANON-KEY" }
}
