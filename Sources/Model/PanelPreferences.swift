import Foundation
import Observation

/// The panel's presentation settings. Collection remains independent of card visibility.
enum PanelCard: String, CaseIterable, Identifiable {
    case memory, thermal, cpu, network, storage, battery
    var id: String { rawValue }
    var title: String {
        switch self {
        case .memory: return "Memory"
        case .thermal: return "Temperature"
        case .cpu: return "CPU"
        case .network: return "Network"
        case .storage: return "Storage"
        case .battery: return "Battery"
        }
    }
}

@MainActor
@Observable
final class PanelPreferences {
    private let defaults: UserDefaults
    private(set) var cards: [PanelCard]
    private(set) var hidden: Set<PanelCard>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = (defaults.stringArray(forKey: "panelCardOrder") ?? []).compactMap(PanelCard.init(rawValue:))
        var unique: [PanelCard] = []
        for card in saved + PanelCard.allCases where !unique.contains(card) { unique.append(card) }
        cards = unique
        hidden = Set((defaults.stringArray(forKey: "panelHiddenCards") ?? []).compactMap(PanelCard.init(rawValue:)))
    }

    func isVisible(_ card: PanelCard) -> Bool { !hidden.contains(card) }

    func setVisible(_ card: PanelCard, visible: Bool) {
        if visible { hidden.remove(card) } else { hidden.insert(card) }
        save()
    }

    func move(_ card: PanelCard, direction: Int) {
        guard let index = cards.firstIndex(of: card) else { return }
        let destination = index + direction
        guard cards.indices.contains(destination) else { return }
        cards.swapAt(index, destination)
        save()
    }

    func reset() {
        cards = PanelCard.allCases
        hidden = []
        save()
    }

    private func save() {
        defaults.set(cards.map(\.rawValue), forKey: "panelCardOrder")
        defaults.set(hidden.map(\.rawValue).sorted(), forKey: "panelHiddenCards")
    }
}
