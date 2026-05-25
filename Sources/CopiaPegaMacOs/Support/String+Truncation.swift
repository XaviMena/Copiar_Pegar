import Foundation

extension String {
    func truncated(to limit: Int) -> String {
        guard count > limit else {
            return self
        }
        let end = index(startIndex, offsetBy: max(0, limit - 1))
        return String(self[..<end]) + "…"
    }
}
