import Foundation

enum PreferencesTests {
    @MainActor
    static func run() {
        let name = "com.local.auspex.preferences-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(["cpu", "cpu", "obsolete"], forKey: "panelCardOrder")
        let preferences = PanelPreferences(defaults: defaults)
        precondition(preferences.cards.count == PanelCard.allCases.count)
        precondition(preferences.cards.first == .cpu, "Keep saved order while repairing duplicates and missing cards")
        preferences.setVisible(.thermal, visible: false)
        preferences.move(.thermal, direction: -1)
        let restored = PanelPreferences(defaults: defaults)
        precondition(!restored.isVisible(.thermal), "Visibility must persist")
        precondition(restored.cards == preferences.cards, "Order must persist")
        restored.move(restored.cards[0], direction: -1)
        precondition(restored.cards == preferences.cards, "Moving the first card up must be harmless")
        restored.reset()
        precondition(restored.cards == PanelCard.allCases && restored.hidden.isEmpty, "Reset must restore every card")
        print("PASS: panel order, visibility, migration and reset preferences")
    }
}
