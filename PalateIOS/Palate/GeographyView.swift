import SwiftUI
import MapKit

struct GeographyPoint: Identifiable {
    let id: UUID
    let title: String
    let place: String
    let detail: String
    let coordinate: CLLocationCoordinate2D
}

enum AtlasCategory { case coffee, wine, scotch
    var palateLabels: [String] {
        switch self {
        case .coffee: ["Sweet", "Bright", "Body", "Roast", "Process"]
        case .wine: ["Fruit", "Body", "Acid", "Tannin", "Oak"]
        case .scotch: ["Smoke", "Fruit", "Rich", "Spice", "Coastal"]
        }
    }
}

struct AtlasRegion: Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let center: CLLocationCoordinate2D
    let boundary: [CLLocationCoordinate2D]
    let knownFor: String
    let expression: String
    let why: String
    var category: AtlasCategory = .wine

    func contains(_ point: GeographyPoint) -> Bool {
        let text = "\(point.place) \(point.title)".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        return aliases.contains { text.contains($0.lowercased()) }
    }

    var cameraRegion: MKCoordinateRegion {
        let latitudes = boundary.map(\.latitude), longitudes = boundary.map(\.longitude)
        let minLatitude = latitudes.min() ?? center.latitude, maxLatitude = latitudes.max() ?? center.latitude
        let minLongitude = longitudes.min() ?? center.longitude, maxLongitude = longitudes.max() ?? center.longitude
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: max(0.8, (maxLatitude - minLatitude) * 2.1), longitudeDelta: max(0.8, (maxLongitude - minLongitude) * 2.1)))
    }

    func categorized(_ category: AtlasCategory) -> AtlasRegion {
        var copy = self
        copy.category = category
        return copy
    }

    var palateValues: [Double] {
        switch category {
        case .coffee:
            switch id {
            case "yirgacheffe": [0.72, 0.92, 0.30, 0.24, 0.68]
            case "cauca", "huila": [0.78, 0.70, 0.55, 0.40, 0.62]
            case "antigua", "huehuetenango": [0.70, 0.65, 0.60, 0.48, 0.48]
            default: [0.72, 0.32, 0.76, 0.56, 0.64]
            }
        case .wine:
            switch id {
            case "willamette", "sonoma": [0.82, 0.42, 0.78, 0.32, 0.38]
            case "barolo": [0.64, 0.68, 0.74, 0.92, 0.42]
            case "burgundy": [0.70, 0.45, 0.72, 0.38, 0.28]
            case "napa": [0.86, 0.88, 0.48, 0.70, 0.72]
            default: [0.74, 0.58, 0.64, 0.48, 0.70]
            }
        case .scotch:
            switch id {
            case "islay": [0.96, 0.45, 0.76, 0.58, 0.92]
            case "speyside": [0.18, 0.84, 0.68, 0.60, 0.26]
            case "campbeltown": [0.50, 0.48, 0.78, 0.58, 0.78]
            case "islands": [0.56, 0.56, 0.62, 0.54, 0.86]
            default: [0.30, 0.62, 0.60, 0.54, 0.42]
            }
        }
    }
}

struct CollectionGeographyView: View {
    let title: String
    let eyebrow: String
    let points: [GeographyPoint]
    let unmappedCount: Int
    let tint: Color
    let symbol: String
    let regions: [AtlasRegion]

    @State private var selection: UUID?
    @State private var selectedRegionID: String?
    @State private var position: MapCameraPosition
    @Namespace private var mapScope

    init(title: String, eyebrow: String, points: [GeographyPoint], unmappedCount: Int, tint: Color, symbol: String, regions: [AtlasRegion] = []) {
        self.title = title
        self.eyebrow = eyebrow
        self.points = points
        self.unmappedCount = unmappedCount
        self.tint = tint
        self.symbol = symbol
        self.regions = regions
        _position = State(initialValue: .region(Self.region(for: points)))
    }

    private var selectedPoint: GeographyPoint? { points.first { $0.id == selection } }
    private var selectedRegion: AtlasRegion? { regions.first { $0.id == selectedRegionID } }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $selection, scope: mapScope) {
                ForEach(regions) { region in
                    MapPolygon(coordinates: region.boundary)
                        .foregroundStyle(tint.opacity(selectedRegion?.id == region.id ? 0.30 : 0.13))
                        .stroke(tint.opacity(selectedRegion?.id == region.id ? 0.90 : 0.48), lineWidth: selectedRegion?.id == region.id ? 2.5 : 1.2)
                    Annotation(region.name, coordinate: region.center) {
                        Button { focus(region) } label: {
                            if selectedRegion?.id == region.id {
                                Text(region.name)
                                    .font(.caption2.weight(.bold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 8).frame(height: 25)
                                    .background(tint, in: Capsule())
                                    .foregroundStyle(Color.black)
                                    .overlay(Capsule().stroke(tint.opacity(0.7)))
                            } else {
                                Circle()
                                    .fill(tint)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(Color.space, lineWidth: 2))
                                    .shadow(color: tint.opacity(0.7), radius: 4)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(points) { point in
                    Marker(point.title, systemImage: symbol, coordinate: point.coordinate)
                        .tint(tint)
                        .tag(point.id)
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted))
            .mapControls { MapCompass(scope: mapScope); MapScaleView(scope: mapScope) }
            .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 10) {
                if let selectedRegion {
                    RegionalCharacterCard(region: selectedRegion, collectionCount: points.filter(selectedRegion.contains).count, tint: tint, symbol: symbol) {
                        selectedRegionID = nil
                    }
                } else if let selectedPoint {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: symbol).foregroundStyle(tint).frame(width: 34, height: 34).background(tint.opacity(0.15), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedPoint.title).font(.headline)
                            Text(selectedPoint.place).font(.subheadline).foregroundStyle(.secondary)
                            Text(selectedPoint.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { selection = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("\(points.count) mapped", systemImage: "mappin.and.ellipse")
                            Spacer()
                            if unmappedCount > 0 { Text("\(unmappedCount) need a location").foregroundStyle(.secondary) }
                        }
                        if !regions.isEmpty {
                            Text("REGIONAL CHARACTER").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(tint)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(regions) { region in
                                        Button { focus(region) } label: {
                                            Text(region.name).font(.caption.weight(.semibold)).padding(.horizontal, 11).frame(height: 30).background(tint.opacity(0.15), in: Capsule()).overlay(Capsule().stroke(tint.opacity(0.35)))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .font(.caption.weight(.semibold)).padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .padding(16)
        }
        .mapScope(mapScope)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .topLeading) {
            Text(eyebrow).font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(tint).padding(.horizontal, 12).frame(height: 30).background(.regularMaterial, in: Capsule()).padding(12)
        }
        .preferredColorScheme(.dark)
    }

    private func focus(_ region: AtlasRegion) {
        selection = nil
        selectedRegionID = region.id
        withAnimation(.easeInOut(duration: 0.45)) { position = .region(region.cameraRegion) }
    }

    private static func region(for points: [GeographyPoint]) -> MKCoordinateRegion {
        guard let first = points.first else { return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 20, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 300)) }
        let latitudes = points.map(\.coordinate.latitude), longitudes = points.map(\.coordinate.longitude)
        let minLat = latitudes.min() ?? first.coordinate.latitude, maxLat = latitudes.max() ?? first.coordinate.latitude
        let minLon = longitudes.min() ?? first.coordinate.longitude, maxLon = longitudes.max() ?? first.coordinate.longitude
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(latitudeDelta: max(3, (maxLat - minLat) * 1.8), longitudeDelta: max(3, (maxLon - minLon) * 1.8))
        )
    }
}

private struct RegionalCharacterCard: View {
    let region: AtlasRegion
    let collectionCount: Int
    let tint: Color
    let symbol: String
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: symbol).foregroundStyle(tint).frame(width: 34, height: 34).background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("REGIONAL CHARACTER").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(tint)
                    Text(region.name).font(.title3.weight(.semibold))
                }
                Spacer()
                Button(action: close) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
            PalatePrintView(region: region, tint: tint)
            RegionalFact(label: "KNOWN FOR", value: region.knownFor)
            RegionalFact(label: "TYPICAL EXPRESSION", value: region.expression)
            RegionalFact(label: "WHY IT MATTERS", value: region.why)
            HStack {
                Label(collectionCount == 1 ? "1 item in your collection" : "\(collectionCount) items in your collection", systemImage: "archivebox.fill")
                Spacer()
                Text("Tendencies, not rules").foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct PalatePrintView: View {
    let region: AtlasRegion
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PALATE PRINT").font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(tint)
                Spacer()
                Text("Regional shorthand").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(Array(zip(region.category.palateLabels, region.palateValues).enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(.white.opacity(0.10)).frame(width: 12, height: 38)
                            Capsule().fill(tint).frame(width: 12, height: max(5, 38 * item.1))
                        }
                        Text(item.0).font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct RegionalFact: View {
    let label, value: String
    var body: some View { VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(.secondary); Text(value).font(.caption).fixedSize(horizontal: false, vertical: true) } }
}

enum RegionalAtlas {
    static let coffee: [AtlasRegion] = [
        region("yirgacheffe", "Yirgacheffe", ["yirgacheffe", "gedeb"], 6.06, 38.32, [5.82, 38.02, 6.28, 38.02, 6.32, 38.62, 5.88, 38.62], "Floral washed coffees and heirloom varieties", "Jasmine, bergamot, citrus, tea-like texture", "High elevation, smallholders, and washed processing create clarity and aromatic lift."),
        region("cauca", "Cauca", ["cauca"], 2.45, -76.61, [1.90, -77.20, 3.05, -77.20, 3.05, -75.95, 1.90, -75.95], "High-altitude Colombian coffees", "Red fruit, caramel, bright acidity, rounded sweetness", "Andean altitude and near-equatorial harvest windows support long, measured cherry development."),
        region("huila", "Huila", ["huila"], 2.54, -75.53, [1.60, -76.15, 3.35, -76.15, 3.35, -74.90, 1.60, -74.90], "Sweet, expressive Colombian lots", "Stone fruit, panela, citrus, silky body", "Mountain valleys and high elevation give producers a wide range of microclimates."),
        region("antigua", "Antigua", ["antigua", "guatemala"], 14.56, -90.73, [14.34, -91.02, 14.82, -91.02, 14.82, -90.45, 14.34, -90.45], "Volcanic Guatemalan coffee", "Cocoa, orange, baking spice, structured sweetness", "Volcanic soils, cool nights, and a pronounced dry season shape a dense, balanced cup."),
        region("huehuetenango", "Huehuetenango", ["huehuetenango"], 15.32, -91.47, [15.00, -91.90, 15.65, -91.90, 15.65, -91.05, 15.00, -91.05], "High-grown Guatemalan coffees", "Apple, toffee, florals, lively acidity", "Very high elevation and dry, warm winds make cultivation possible in exceptional terrain."),
        region("cerrado", "Cerrado Mineiro", ["cerrado", "brazil"], -18.46, -46.07, [-19.60, -47.40, -17.30, -47.40, -17.30, -44.90, -19.60, -44.90], "Consistent Brazilian naturals", "Chocolate, hazelnut, low-toned fruit, creamy body", "A dry harvest season and broad plateaus enable reliable sun-dried processing.")
    ].map { $0.categorized(.coffee) }

    static let wine: [AtlasRegion] = [
        region("willamette", "Willamette Valley", ["willamette", "oregon"], 45.23, -123.14, [44.82, -123.65, 45.72, -123.65, 45.72, -122.70, 44.82, -122.70], "Cool-climate Pinot Noir and Chardonnay", "Red cherry, rose, forest floor, bright acidity", "Pacific influence and long growing seasons preserve freshness and aromatic detail."),
        region("sonoma", "Sonoma County", ["sonoma"], 38.44, -122.73, [37.95, -123.35, 38.95, -123.35, 38.95, -122.15, 37.95, -122.15], "Pinot Noir, Chardonnay, and coastal varieties", "Red fruit, lifted florals, delicate texture", "Fog and cool evenings moderate ripening across diverse coastal and inland sites."),
        region("barolo", "Barolo", ["barolo", "piedmont", "piemonte"], 44.63, 7.95, [44.45, 7.70, 44.82, 7.70, 44.82, 8.20, 44.45, 8.20], "Nebbiolo from the Langhe hills", "Rose, sour cherry, tar, firm tannin", "Calcareous-clay soils and a continental climate give Nebbiolo its perfume and structure."),
        region("burgundy", "Burgundy", ["burgundy", "bourgogne"], 47.05, 4.38, [46.15, 3.85, 47.90, 3.85, 47.90, 5.10, 46.15, 5.10], "Site-driven Pinot Noir and Chardonnay", "Red berries, earth, savory minerality, fine texture", "A mosaic of small vineyard sites and limestone-rich soils puts nuance ahead of power."),
        region("napa", "Napa Valley", ["napa"], 38.50, -122.27, [38.20, -122.55, 38.75, -122.55, 38.75, -122.10, 38.20, -122.10], "Cabernet Sauvignon and warm-climate reds", "Cassis, blackberry, cedar, concentrated texture", "Valley-floor heat meets cooling marine influence, allowing ripeness without losing all freshness."),
        region("rioja", "Rioja", ["rioja"], 42.29, -2.54, [41.85, -3.15, 42.72, -3.15, 42.72, -1.85, 41.85, -1.85], "Tempranillo with oak-aged tradition", "Red cherry, dried herbs, vanilla, supple tannin", "Atlantic and Mediterranean influences meet around the Ebro, while aging style shapes the final voice."),
        region("douro", "Douro Valley", ["douro", "porto", "port"], 41.17, -7.55, [40.82, -8.25, 41.62, -8.25, 41.62, -6.55, 40.82, -6.55], "Terraced Portuguese reds and Port", "Black fruit, violet, schist-driven mineral depth, firm structure", "Steep, hot schist terraces along the Douro create concentrated fruit; altitude and subregion bring contrast."),
        region("vinho-verde", "Vinho Verde", ["vinho verde", "minho"], 41.72, -8.38, [41.25, -9.05, 42.05, -9.05, 42.05, -7.85, 41.25, -7.85], "Light, fresh northern Portuguese wines", "Citrus, green apple, white flowers, crisp acidity", "Atlantic influence and a cool, wet northern climate help preserve brightness and low-weight refreshment."),
        region("bordeaux", "Bordeaux", ["bordeaux"], 44.84, -0.58, [44.35, -1.30, 45.30, -1.30, 45.30, 0.10, 44.35, 0.10], "Cabernet- and Merlot-based blends", "Blackcurrant, plum, cedar, graphite, structured tannin", "Maritime moderation, gravel and clay soils, and blending traditions shape a broad range of classic styles."),
        region("loire", "Loire Valley", ["loire", "sancerre", "vouvray", "chinon"], 47.23, 0.30, [46.45, -2.10, 47.95, -2.10, 47.95, 2.60, 46.45, 2.60], "Chenin Blanc, Sauvignon Blanc, Cabernet Franc", "Citrus, orchard fruit, herbs, chalk, lively freshness", "The long river corridor spans many soils and climates, with cool conditions often foregrounding acidity and aroma."),
        region("champagne", "Champagne", ["champagne"], 49.04, 3.96, [48.65, 3.30, 49.48, 3.30, 49.48, 4.95, 48.65, 4.95], "Traditional-method sparkling wine", "Lemon, apple, brioche, chalk, fine mousse", "A northern climate and chalk-rich soils make high-acid base wines suited to extended bottle aging."),
        region("mosel", "Mosel", ["mosel"], 49.80, 6.80, [49.30, 5.85, 50.45, 5.85, 50.45, 7.55, 49.30, 7.55], "Steep-slope German Riesling", "Lime, green apple, slate, floral perfume, electric acidity", "Cool temperatures and heat-reflecting slate slopes allow Riesling to ripen while retaining remarkable tension."),
        region("tuscany", "Tuscany", ["tuscany", "toscana", "chianti", "brunello"], 43.45, 11.05, [42.65, 9.95, 44.35, 9.95, 44.35, 12.20, 42.65, 12.20], "Sangiovese and central Italian reds", "Sour cherry, dried herbs, leather, savory tannin", "Hills, Mediterranean light, and varied galestro and alberese soils give Sangiovese both perfume and grip."),
        region("veneto", "Veneto", ["veneto", "valpolicella", "soave", "prosecco"], 45.53, 11.72, [45.05, 10.65, 46.25, 10.65, 46.25, 12.80, 45.05, 12.80], "Prosecco, Soave, Amarone and Valpolicella", "Citrus or stone fruit through to dried cherry and chocolate", "A wide regional sweep from Alpine foothills to the Adriatic supports contrasting grapes and winemaking styles."),
        region("priorat", "Priorat", ["priorat"], 41.24, 0.84, [40.98, 0.53, 41.48, 0.53, 41.48, 1.15, 40.98, 1.15], "Concentrated Garnacha and Carignan blends", "Black fruit, herbs, licorice, mineral grip", "Steep slopes and distinctive llicorella slate create naturally low yields and a powerful mineral signature."),
        region("ribera", "Ribera del Duero", ["ribera del duero"], 41.63, -3.70, [41.30, -4.35, 42.00, -4.35, 42.00, -3.00, 41.30, -3.00], "Tempranillo from high-elevation Castilla", "Blackberry, plum, tobacco, firm tannin", "High altitude brings warm days and cold nights, balancing ripeness with acidity in continental conditions."),
        region("mendoza", "Mendoza", ["mendoza", "uco"], -32.89, -68.85, [-34.80, -70.10, -31.45, -70.10, -31.45, -67.40, -34.80, -67.40], "Argentine Malbec and high-altitude reds", "Black plum, violet, cocoa, broad texture", "Andean altitude, dry continental conditions, varied soils, and snowmelt irrigation shape a diverse wine landscape."),
        region("barossa", "Barossa Valley", ["barossa"], -34.53, 138.96, [-34.90, 138.50, -34.20, 138.50, -34.20, 139.40, -34.90, 139.40], "Ripe Australian Shiraz", "Blackberry, plum, dark chocolate, sweet spice", "Warm conditions and old-vine material often create generous, full-bodied wines with deep fruit concentration."),
        region("marlborough", "Marlborough", ["marlborough"], -41.51, 173.96, [-42.05, 173.20, -41.05, 173.20, -41.05, 174.85, -42.05, 174.85], "Vivid Sauvignon Blanc and cool-climate Pinot", "Passionfruit, citrus, herbs, mineral freshness", "High sunshine, low rainfall, cool nights, and free-draining soils support intense aromatics and bright acidity."),
        region("central-otago", "Central Otago", ["central otago"], -45.03, 169.20, [-45.75, 168.20, -44.35, 168.20, -44.35, 170.15, -45.75, 170.15], "Southern New Zealand Pinot Noir", "Dark cherry, plum, violet, fine tannin", "A dry continental climate, high elevation, and dramatic day–night shifts create ripe yet energetic Pinot."),
        region("stellenbosch", "Stellenbosch", ["stellenbosch"], -33.93, 18.86, [-34.28, 18.45, -33.58, 18.45, -33.58, 19.35, -34.28, 19.35], "South African Cabernet, Chenin Blanc, and blends", "Cassis, plum, herbs, fresh acidity, savory earth", "Mountain sites and cooling maritime influence meet diverse soils close to the Cape."),
        region("maipo", "Maipo Valley", ["maipo"], -33.55, -70.57, [-34.15, -71.30, -32.95, -71.30, -32.95, -69.85, -34.15, -69.85], "Chilean Cabernet Sauvignon", "Cassis, mint, cedar, structured tannin", "Andean snowmelt, warm sunshine, and significant night cooling help Cabernet retain definition and lift.")
    ]

    static let scotch: [AtlasRegion] = [
        region("islay", "Islay", ["islay"], 55.78, -6.24, [55.55, -6.70, 56.00, -6.70, 56.00, -5.85, 55.55, -5.85], "Peated maritime single malts", "Smoke, brine, iodine, seaweed, citrus", "Island peat, coastal maturation, and marine air frequently shape a powerful coastal character."),
        region("speyside", "Speyside", ["speyside"], 57.45, -3.13, [57.05, -3.85, 57.85, -3.85, 57.85, -2.55, 57.05, -2.55], "Fruit-forward, often sherried single malts", "Orchard fruit, honey, malt, dried fruit, spice", "The sheltered valley and its concentration of distilleries have made it Scotland's most recognized malt region."),
        region("highlands", "Highlands", ["highland", "highlands"], 57.12, -4.71, [56.40, -6.25, 58.35, -6.25, 58.35, -2.80, 56.40, -2.80], "Scotland's broadest, most varied region", "Heather, malt, fruit, spice, sometimes peat", "A vast geography covers coastal, mountainous, and inland climates, so style varies considerably."),
        region("lowlands", "Lowlands", ["lowland", "lowlands"], 55.86, -4.25, [55.30, -5.25, 56.35, -5.25, 56.35, -2.65, 55.30, -2.65], "Traditionally lighter, approachable malts", "Grass, citrus, cereal, gentle florals", "Lower elevation and historic production styles often favor a softer, more delicate profile."),
        region("campbeltown", "Campbeltown", ["campbeltown"], 55.43, -5.61, [55.22, -5.90, 55.62, -5.90, 55.62, -5.30, 55.22, -5.30], "Distinctive coastal, oily malts", "Salt, engine oil, dried fruit, smoke", "A former whisky capital on the Kintyre peninsula, its few remaining distilleries retain a singular style."),
        region("islands", "Islands", ["islands", "island", "orkney", "skye", "arran", "jura"], 57.48, -6.20, [56.70, -7.30, 58.20, -7.30, 58.20, -5.45, 56.70, -5.45], "Coastal island single malts", "Sea spray, heather, pepper, variable smoke", "This informal grouping spans several islands, united more by maritime influence than a single production style.")
    ].map { $0.categorized(.scotch) }

    private static func region(_ id: String, _ name: String, _ aliases: [String], _ latitude: Double, _ longitude: Double, _ box: [Double], _ knownFor: String, _ expression: String, _ why: String) -> AtlasRegion {
        let latitudes = stride(from: 0, to: box.count, by: 2).map { box[$0] }
        let longitudes = stride(from: 1, to: box.count, by: 2).map { box[$0] }
        let minimumLatitude = latitudes.min() ?? latitude, maximumLatitude = latitudes.max() ?? latitude
        let minimumLongitude = longitudes.min() ?? longitude, maximumLongitude = longitudes.max() ?? longitude
        let latitudeSpan = maximumLatitude - minimumLatitude, longitudeSpan = maximumLongitude - minimumLongitude
        let outline = [
            CLLocationCoordinate2D(latitude: minimumLatitude + latitudeSpan * 0.18, longitude: minimumLongitude),
            CLLocationCoordinate2D(latitude: minimumLatitude + latitudeSpan * 0.02, longitude: minimumLongitude + longitudeSpan * 0.27),
            CLLocationCoordinate2D(latitude: minimumLatitude + latitudeSpan * 0.13, longitude: maximumLongitude - longitudeSpan * 0.08),
            CLLocationCoordinate2D(latitude: minimumLatitude + latitudeSpan * 0.43, longitude: maximumLongitude),
            CLLocationCoordinate2D(latitude: maximumLatitude - latitudeSpan * 0.11, longitude: maximumLongitude - longitudeSpan * 0.14),
            CLLocationCoordinate2D(latitude: maximumLatitude, longitude: maximumLongitude - longitudeSpan * 0.40),
            CLLocationCoordinate2D(latitude: maximumLatitude - latitudeSpan * 0.07, longitude: minimumLongitude + longitudeSpan * 0.13),
            CLLocationCoordinate2D(latitude: minimumLatitude + latitudeSpan * 0.58, longitude: minimumLongitude)
        ]
        return AtlasRegion(id: id, name: name, aliases: aliases, center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), boundary: outline, knownFor: knownFor, expression: expression, why: why)
    }
}

enum OriginResolver {
    static func coordinate(for place: String) -> CLLocationCoordinate2D? {
        let text = place.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        let locations: [(terms: [String], latitude: Double, longitude: Double)] = [
            (["gedeb", "yirgacheffe"], 5.93, 38.27), (["ethiopia"], 8.98, 38.76), (["cauca"], 2.45, -76.61), (["colombia"], 4.57, -74.30),
            (["kenya"], -0.02, 37.91), (["guatemala"], 15.78, -90.23), (["costa rica"], 9.75, -83.75), (["brazil"], -14.24, -51.93),
            (["rwanda"], -1.94, 29.87), (["burundi"], -3.37, 29.92), (["panama"], 8.54, -80.78), (["honduras"], 15.20, -86.24),
            (["peru"], -9.19, -75.02), (["indonesia"], -0.79, 113.92), (["mexico"], 23.63, -102.55), (["yemen"], 15.55, 48.52),
            (["willamette", "oregon"], 45.23, -123.14), (["piedmont", "barolo"], 44.70, 7.95), (["bordeaux"], 44.84, -0.58), (["burgundy", "bourgogne"], 47.05, 4.38),
            (["champagne"], 49.04, 3.96), (["napa"], 38.50, -122.27), (["sonoma"], 38.29, -122.46), (["tuscany", "toscana"], 43.77, 11.25),
            (["rioja"], 42.29, -2.54), (["mosel"], 49.80, 6.80), (["barossa"], -34.53, 138.96), (["mendoza"], -32.89, -68.85),
            (["speyside"], 57.45, -3.13), (["islay"], 55.76, -6.18), (["campbeltown"], 55.43, -5.61), (["lowland"], 55.86, -4.25),
            (["highland"], 57.12, -4.71), (["island"], 57.48, -6.20), (["scotland"], 56.49, -4.20)
        ]
        guard let match = locations.first(where: { entry in entry.terms.contains(where: text.contains) }) else { return nil }
        return CLLocationCoordinate2D(latitude: match.latitude, longitude: match.longitude)
    }
}

extension Array where Element == CoffeeBag {
    var geographyPoints: [GeographyPoint] { compactMap { bag in
        guard let coordinate = OriginResolver.coordinate(for: bag.origin) else { return nil }
        return GeographyPoint(id: bag.id, title: bag.name, place: bag.origin, detail: "\(bag.roaster) · \(bag.process)", coordinate: coordinate)
    } }
}

extension Array where Element == WineBottle {
    var geographyPoints: [GeographyPoint] { compactMap { bottle in
        let stored = CLLocationCoordinate2D(latitude: bottle.latitude, longitude: bottle.longitude)
        guard let coordinate = (abs(stored.latitude) > 0.01 || abs(stored.longitude) > 0.01) ? stored : OriginResolver.coordinate(for: "\(bottle.region) \(bottle.country)") else { return nil }
        return GeographyPoint(id: bottle.id, title: bottle.name, place: "\(bottle.region), \(bottle.country)", detail: "\(bottle.producer) · \(bottle.vintage)", coordinate: coordinate)
    } }
}

extension Array where Element == ScotchBottle {
    var geographyPoints: [GeographyPoint] { compactMap { bottle in
        let stored = CLLocationCoordinate2D(latitude: bottle.latitude, longitude: bottle.longitude)
        guard let coordinate = OriginResolver.coordinate(for: "\(bottle.region) Scotland") ?? ((abs(stored.latitude) > 0.01 || abs(stored.longitude) > 0.01) ? stored : nil) else { return nil }
        return GeographyPoint(id: bottle.id, title: bottle.name, place: "\(bottle.region), Scotland", detail: "\(bottle.distillery) · \(bottle.ageStatement)", coordinate: coordinate)
    } }
}
