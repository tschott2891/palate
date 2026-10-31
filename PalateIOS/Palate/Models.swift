import Foundation

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
