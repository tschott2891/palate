import Foundation
import Combine

enum TastingCategory: String, Codable, CaseIterable, Identifiable {
    case coffee, wine, scotch

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// A snapshot of a tasting, kept separately from collection metadata so old notes
/// still make sense if a bottle or bag is later edited or removed.
struct TastingRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var category: TastingCategory
    var productID: UUID
    var productName: String
    var producerName: String
    var date: Date = .now
    var context: String
    var measurementLabel: String? = nil
    var measurementSeconds: Int? = nil
    var descriptors: [String]
    var rating: Int
    var note: String

    var hasNote: Bool { !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

@MainActor
final class TastingHistoryStore: ObservableObject {
    @Published private(set) var records: [TastingRecord] = []

    private let storageKey = "tastingHistory.v1"

    init(defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TastingRecord].self, from: data) else { return }
        records = decoded.sorted { $0.date > $1.date }
    }

    func add(_ record: TastingRecord) {
        records.insert(record, at: 0)
        persist()
    }

    func records(for productID: UUID) -> [TastingRecord] {
        records.filter { $0.productID == productID }.sorted { $0.date > $1.date }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct PalateProfileRequest: Codable {
    struct RecentTasting: Codable {
        let date: Date
        let descriptors: [String]
        let rating: Int
        let note: String
        let context: String
        let measurementLabel: String?
        let measurementSeconds: Int?
    }

    let category: TastingCategory
    let productName: String
    let producer: String
    let attributes: [String: String]
    let recentTastings: [RecentTasting]
    let labelImageBase64: String?

    static func coffee(_ bag: CoffeeBag, records: [TastingRecord]) -> Self {
        Self(category: .coffee, productName: bag.name, producer: bag.roaster, attributes: ["origin": bag.originDetail, "process": bag.process, "roaster notes": bag.notes.joined(separator: ", "), "last recipe": "\(Int(bag.lastDose))g coffee · \(Int(bag.lastWater))g water · grind \(bag.lastGrind)"], recentTastings: history(records), labelImageBase64: bag.imageData?.base64EncodedString())
    }

    static func wine(_ bottle: WineBottle, records: [TastingRecord]) -> Self {
        Self(category: .wine, productName: bottle.name, producer: bottle.producer, attributes: ["vintage": bottle.vintage, "grapes": bottle.grapes, "region": bottle.region, "country": bottle.country, "producer notes": bottle.notes.joined(separator: ", ")], recentTastings: history(records), labelImageBase64: bottle.imageData?.base64EncodedString())
    }

    static func scotch(_ bottle: ScotchBottle, records: [TastingRecord]) -> Self {
        Self(category: .scotch, productName: bottle.name, producer: bottle.distillery, attributes: ["age statement": bottle.ageStatement, "region": bottle.region, "cask": bottle.cask, "ABV": bottle.abv, "distillery notes": bottle.notes.joined(separator: ", ")], recentTastings: history(records), labelImageBase64: bottle.imageData?.base64EncodedString())
    }

    private static func history(_ records: [TastingRecord]) -> [RecentTasting] {
        records.prefix(8).map { RecentTasting(date: $0.date, descriptors: $0.descriptors, rating: $0.rating, note: $0.note, context: $0.context, measurementLabel: $0.measurementLabel, measurementSeconds: $0.measurementSeconds) }
    }
}

struct PalateProfile: Codable {
    struct Identity: Codable { let snapshot: String; let confidence: Int; let evidence: String }
    struct SensoryGroup: Codable { let name: String; let notes: [String]; let basis: String }
    let identity: Identity
    let summary: String
    let story: String
    let sensory: [SensoryGroup]
    let tastingPrompts: [String]
    let preparation: [String]
    let personalization: String
    let discovery: String
    let caveats: [String]
}

enum PalateIntelligenceError: LocalizedError {
    case notConfigured, invalidResponse, service(String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: "AI profiles need a Palate Intelligence service URL before they can be generated."
        case .invalidResponse: "Palate received an unreadable profile. Please try again."
        case .service(let message): message
        }
    }
}

enum PalateIntelligenceService {
    static func profile(for request: PalateProfileRequest) async throws -> PalateProfile {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "PALATE_INTELLIGENCE_URL") as? String,
              let url = URL(string: rawURL), !rawURL.isEmpty else { throw PalateIntelligenceError.notConfigured }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw PalateIntelligenceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(PalateServiceError.self, from: data).error) ?? "Palate Intelligence is temporarily unavailable."
            throw PalateIntelligenceError.service(message)
        }
        guard let profile = try? JSONDecoder().decode(PalateProfile.self, from: data) else { throw PalateIntelligenceError.invalidResponse }
        return profile
    }

    private struct PalateServiceError: Decodable { let error: String }
}

struct PalateLabelEnrichment: Codable {
    struct Field: Codable, Hashable { let label: String; let value: String; let confidence: Int; let basis: String }
    let fields: [Field]
    let caveats: [String]
}

enum PalateLabelEnrichmentService {
    static func enrich(category: TastingCategory, recognizedLines: [String], imageData: Data) async throws -> PalateLabelEnrichment {
        guard let rawURL = Bundle.main.object(forInfoDictionaryKey: "PALATE_INTELLIGENCE_URL") as? String,
              let url = URL(string: rawURL), !rawURL.isEmpty else { throw PalateIntelligenceError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(EnrichmentRequest(mode: "enrich_label", category: category, recognizedLines: recognizedLines, labelImageBase64: imageData.base64EncodedString()))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PalateIntelligenceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ServiceError.self, from: data).error) ?? "Palate Intelligence is temporarily unavailable."
            throw PalateIntelligenceError.service(message)
        }
        guard let enrichment = try? JSONDecoder().decode(PalateLabelEnrichment.self, from: data) else { throw PalateIntelligenceError.invalidResponse }
        return enrichment
    }

    private struct EnrichmentRequest: Codable { let mode: String; let category: TastingCategory; let recognizedLines: [String]; let labelImageBase64: String }
    private struct ServiceError: Decodable { let error: String }
}

struct CoffeeBag: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var roaster: String
    var origin: String
    var process: String
    var notes: [String]
    var accent: String
    var estate: String? = nil
    var county: String? = nil
    var roastDate: Date? = nil
    var imageData: Data? = nil
    var lastDose: Double = 20
    var lastWater: Double = 320
    var lastGrind: String = "7.5"
    var lastTip: String = "Keep this recipe close."
    var active: Bool = true

    var originDetail: String {
        [estate, county, origin].compactMap { value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }

    init(id: UUID = UUID(), name: String, roaster: String, origin: String, process: String, notes: [String], accent: String, estate: String? = nil, county: String? = nil, roastDate: Date? = nil, imageData: Data? = nil, lastDose: Double = 20, lastWater: Double = 320, lastGrind: String = "7.5", lastTip: String = "Keep this recipe close.", active: Bool = true) {
        self.id = id; self.name = name; self.roaster = roaster; self.origin = origin; self.process = process; self.notes = notes; self.accent = accent; self.estate = estate; self.county = county; self.roastDate = roastDate; self.imageData = imageData; self.lastDose = lastDose; self.lastWater = lastWater; self.lastGrind = lastGrind; self.lastTip = lastTip; self.active = active
    }

    enum CodingKeys: String, CodingKey { case id, name, roaster, origin, process, notes, accent, estate, county, roastDate, imageData, lastDose, lastWater, lastGrind, lastTip, active }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decode(String.self, forKey: .name)
        roaster = try values.decode(String.self, forKey: .roaster)
        origin = try values.decode(String.self, forKey: .origin)
        process = try values.decode(String.self, forKey: .process)
        notes = try values.decodeIfPresent([String].self, forKey: .notes) ?? []
        accent = try values.decodeIfPresent(String.self, forKey: .accent) ?? "indigo"
        estate = try values.decodeIfPresent(String.self, forKey: .estate)
        county = try values.decodeIfPresent(String.self, forKey: .county)
        roastDate = try values.decodeIfPresent(Date.self, forKey: .roastDate)
        imageData = try values.decodeIfPresent(Data.self, forKey: .imageData)
        lastDose = try values.decodeIfPresent(Double.self, forKey: .lastDose) ?? 20
        lastWater = try values.decodeIfPresent(Double.self, forKey: .lastWater) ?? 320
        lastGrind = try values.decodeIfPresent(String.self, forKey: .lastGrind) ?? "7.5"
        lastTip = try values.decodeIfPresent(String.self, forKey: .lastTip) ?? "Keep this recipe close."
        active = try values.decodeIfPresent(Bool.self, forKey: .active) ?? true
    }

    static let examples = [
        CoffeeBag(name: "Ethiopia · Worka Sakaro", roaster: "Olympia Coffee", origin: "Gedeb, Ethiopia", process: "Washed", notes: ["Jasmine", "Peach", "Bergamot"], accent: "indigo", lastTip: "A touch finer next time."),
        CoffeeBag(name: "Colombia · El Paraíso", roaster: "Onyx Coffee Lab", origin: "Cauca, Colombia", process: "Anaerobic", notes: ["Strawberry", "Cacao", "Lychee"], accent: "plum")
    ]
}

struct BrewRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var coffeeID: UUID
    var date: Date = .now
    var dose: Double
    var water: Double
    var grinder: String
    var setting: String
    var tags: [String]
    var note: String
}

enum BrewType: String, CaseIterable, Identifiable {
    case v60 = "V60"
    case espresso = "Espresso"
    case aeropress = "AeroPress"
    case chemex = "Chemex"
    case mokaPot = "Moka Pot"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .v60: "v.circle"
        case .espresso: "cup.and.saucer.fill"
        case .aeropress: "arrow.down.to.line"
        case .chemex: "flask.fill"
        case .mokaPot: "flame.fill"
        }
    }
    var defaultDose: Double { self == .espresso ? 18 : 20 }
    var defaultOutput: Double {
        switch self {
        case .v60, .chemex: 320
        case .espresso: 36
        case .aeropress: 250
        case .mokaPot: 180
        }
    }
    var defaultTemperature: Double { self == .espresso ? 200 : 200 }
    var outputLabel: String { self == .espresso ? "Yield" : "Water" }
}

enum V60Recipe: String, CaseIterable, Identifiable {
    case hoffmann = "Hoffmann-style"
    case single = "Single pour"
    case fourSix = "4:6 method"
    var id: String { rawValue }
    var caption: String {
        switch self {
        case .hoffmann: "Two pours, gentle swirl · ~3:30"
        case .single: "One continuous pour · ~3:00"
        case .fourSix: "Balanced five-pour sequence · ~3:30"
        }
    }
    var stages: [BrewStage] {
        switch self {
        case .hoffmann: [
            BrewStage(name: "Bloom", seconds: 45, weight: 60, technique: "Small circles", instruction: "Bloom gently until all grounds are wet."),
            BrewStage(name: "First pour", seconds: 30, weight: 200, technique: "Larger circles", instruction: "Pour steadily, keeping the bed level."),
            BrewStage(name: "Second pour", seconds: 30, weight: 320, technique: "Center pour", instruction: "Finish near the center; avoid the paper."),
            BrewStage(name: "Drawdown", seconds: 105, weight: 320, technique: "Wait & observe", instruction: "Let it draw down. A gentle swirl is enough.")]
        case .single: [BrewStage(name: "Bloom", seconds: 45, weight: 60, technique: "Small circles", instruction: "Bloom gently until all grounds are wet."), BrewStage(name: "Pour", seconds: 75, weight: 320, technique: "Slow spiral", instruction: "Pour with an even, unhurried spiral."), BrewStage(name: "Drawdown", seconds: 60, weight: 320, technique: "Wait & observe", instruction: "Let the cup settle.")]
        case .fourSix: [BrewStage(name: "Bloom", seconds: 45, weight: 60, technique: "Small circles", instruction: "Bloom gently until all grounds are wet."), BrewStage(name: "Pour one", seconds: 30, weight: 120, technique: "Small circles", instruction: "Pour gently and evenly."), BrewStage(name: "Pour two", seconds: 30, weight: 180, technique: "Larger circles", instruction: "Build sweetness with a steady pour."), BrewStage(name: "Pour three", seconds: 30, weight: 250, technique: "Center pour", instruction: "Keep the bed level."), BrewStage(name: "Finish", seconds: 75, weight: 320, technique: "Center pour", instruction: "Finish calmly, then let it draw down.")]
        }
    }
}

struct BrewStage { let name: String; let seconds: Int; let weight: Int; let technique: String; let instruction: String }

enum GrinderProfile: String, CaseIterable, Identifiable {
    case timemore078s = "Timemore 078S"
    case baratzaEncore = "Baratza Encore"
    case timemoreC3s = "Timemore Chestnut C3S"

    var id: String { rawValue }

    var v60Default: String {
        switch self {
        case .timemore078s: "14"
        case .baratzaEncore: "20"
        case .timemoreC3s: "7 clicks"
        }
    }

    var espressoDefault: String? {
        switch self {
        case .timemore078s: "4"
        case .baratzaEncore, .timemoreC3s: nil
        }
    }

    var defaultSummary: String {
        if let espressoDefault { return "V60: \(v60Default) · Espresso: \(espressoDefault)" }
        return "V60: \(v60Default)"
    }
}

struct WineBottle: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String; var producer: String; var vintage: String; var grapes: String; var region: String; var country: String
    var latitude: Double; var longitude: Double; var notes: [String]
    var imageData: Data? = nil
    static let examples = [
        WineBottle(name: "Willamette Valley Pinot Noir", producer: "Eyrie Vineyards", vintage: "2022", grapes: "Pinot Noir", region: "Willamette Valley, Oregon", country: "United States", latitude: 45.23, longitude: -123.14, notes: ["Cherry", "Rose", "Forest floor"]),
        WineBottle(name: "Barolo", producer: "G.D. Vajra", vintage: "2019", grapes: "Nebbiolo", region: "Piedmont", country: "Italy", latitude: 44.70, longitude: 7.95, notes: ["Tar", "Rose", "Sour cherry"])
    ]
}

struct ScotchBottle: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String; var distillery: String; var ageStatement: String; var region: String; var cask: String; var abv: String
    var latitude: Double; var longitude: Double; var notes: [String]
    var imageData: Data? = nil
    static let examples = [
        ScotchBottle(name: "The Balvenie DoubleWood", distillery: "The Balvenie", ageStatement: "12 years", region: "Speyside", cask: "Bourbon & sherry casks", abv: "40% ABV", latitude: 57.45, longitude: -3.13, notes: ["Honey", "Dried fruit", "Cinnamon"]),
        ScotchBottle(name: "Laphroaig 10", distillery: "Laphroaig", ageStatement: "10 years", region: "Islay", cask: "Ex-bourbon barrels", abv: "43% ABV", latitude: 55.63, longitude: -6.15, notes: ["Peat smoke", "Seaweed", "Vanilla"])
    ]
}
