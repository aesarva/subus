import Foundation

public enum Monogram {
    public static func letter(for name: String) -> String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "?" }
        return String(first).uppercased()
    }

    /// FNV-1a 64 по UTF-8 нормализованного имени: стабильно между запусками (в отличие от `hashValue`).
    public static func colorIndex(for name: String, paletteCount: Int) -> Int {
        guard paletteCount > 0 else { return 0 }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return Int(hash % UInt64(paletteCount))
    }
}
