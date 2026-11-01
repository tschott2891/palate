import SwiftUI
import UIKit
import Combine
import MapKit
import PhotosUI

struct ContentView: View {
    @State private var selectedTab: RootTab = .home
    @StateObject private var tastingHistory = TastingHistoryStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView { selectedTab = $0 }
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(RootTab.home)
            CoffeeShelfView()
                .tabItem { Label("Coffee", systemImage: "cup.and.saucer.fill") }
                .tag(RootTab.coffee)
            WineShelfView()
                .tabItem { Label("Wine", systemImage: "wineglass.fill") }
                .tag(RootTab.wine)
            ScotchShelfView()
                .tabItem { Label("Scotch", systemImage: "flame.fill") }
                .tag(RootTab.scotch)
        }
        .tint(Color.starlight)
        .preferredColorScheme(.dark)
        .toolbarBackground(Color.space, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .environmentObject(tastingHistory)
    }
}

private enum RootTab: Hashable { case home, coffee, wine, scotch }

private struct HomeView: View {
    @AppStorage("coffeeBags") private var storedCoffee = ""
    @AppStorage("wineBottles") private var storedWine = ""
    @AppStorage("scotchBottles") private var storedScotch = ""
    let open: (RootTab) -> Void

    private var coffees: [CoffeeBag] { decoded(storedCoffee, fallback: CoffeeBag.examples) }
    private var wines: [WineBottle] { decoded(storedWine, fallback: WineBottle.examples) }
    private var scotches: [ScotchBottle] { decoded(storedScotch, fallback: ScotchBottle.examples) }
    private var total: Int { coffees.count + wines.count + scotches.count }

    var body: some View {
        ZStack {
            Color.space.ignoresSafeArea()
            RadialGradient(colors: [Color.starlight.opacity(0.14), .clear], center: .topTrailing, startRadius: 10, endRadius: 430).ignoresSafeArea()
            LinearGradient(colors: [.clear, Color.coffee.opacity(0.08), Color.wine.opacity(0.07)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    AppBrand(actionSymbol: "sparkles")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("YOUR TASTING COMPANION").eyebrow()
                        Text("Taste with\nintention.")
                            .font(.system(size: 52, weight: .regular, design: .serif))
                            .tracking(-1.5)
                            .lineSpacing(-3)
                        Text("Capture what you tried, how you prepared it, and what you want to remember next time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 340, alignment: .leading)
                    }

                    Button { open(.coffee) } label: {
                        HStack(spacing: 17) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.title2)
                                .foregroundStyle(.black)
                                .frame(width: 50, height: 50)
                                .background(Color.starlight, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BREW SOMETHING").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(Color.starlight)
                                Text("Start with coffee").font(.title3.weight(.semibold)).foregroundStyle(.primary)
                                Text("Choose a bag and build your recipe").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.right").foregroundStyle(Color.starlight)
                        }
                        .padding(18)
                        .background(LinearGradient(colors: [Color.coffee.opacity(0.24), Color.starlight.opacity(0.08)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.coffee.opacity(0.32)))
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("YOUR COLLECTIONS").eyebrow()
                                Text("What are you tasting?").font(.title3.weight(.semibold))
                            }
                            Spacer()
                            Text("\(total) saved").font(.caption).foregroundStyle(.secondary)
                        }

                        HomeCollectionCard(title: "Coffee", subtitle: "Brew, refine, remember", count: "\(coffees.filter(\.active).count) active bags", symbol: "cup.and.saucer.fill", tint: .coffee) { open(.coffee) }
                        HomeCollectionCard(title: "Wine", subtitle: "Producers, vintages & places", count: "\(wines.count) bottles", symbol: "wineglass.fill", tint: .wine) { open(.wine) }
                        HomeCollectionCard(title: "Scotch", subtitle: "Distilleries, casks & regions", count: "\(scotches.count) bottles", symbol: "flame.fill", tint: .scotch) { open(.scotch) }
                    }

                    HStack(spacing: 14) {
                        Image(systemName: "map.fill").foregroundStyle(Color.sage)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EXPLORE BY PLACE").eyebrow().foregroundStyle(Color.sage)
                            Text("Origin maps live inside each collection.").font(.subheadline)
                        }
                        Spacer()
                    }
                    .padding(18)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08)))
                }
                .padding(20)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func decoded<T: Decodable>(_ value: String, fallback: [T]) -> [T] {
        guard !value.isEmpty, let data = value.data(using: .utf8), let result = try? JSONDecoder().decode([T].self, from: data) else { return fallback }
        return result
    }
}

private struct HomeCollectionCard: View {
    let title, subtitle, count, symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 46, height: 46)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(count).font(.caption.weight(.medium)).foregroundStyle(tint)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

private struct CoffeeShelfView: View {
    @AppStorage("coffeeBags") private var storedBags = ""
    @State private var bags: [CoffeeBag] = []
    @State private var path = NavigationPath()
    @State private var showAdd = false
    @State private var pendingDelete: CoffeeBag?
    @State private var editingBag: CoffeeBag?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.space.ignoresSafeArea()
                LinearGradient(colors: [Color.coffee.opacity(0.16), .clear, Color.starlight.opacity(0.08)], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        AppBrand(actionSymbol: "slider.horizontal.3")
                        VStack(alignment: .leading, spacing: 8) { Text("COFFEE").eyebrow(); Text("Your coffee").displayTitle(); Text("\(bags.filter(\.active).count) bags in rotation").supportingText() }
                        HStack { VStack(alignment: .leading, spacing: 3) { Text("ACTIVE BAGS").eyebrow(); Text("Choose a bag to brew").font(.headline) }; Spacer(); NavigationLink { CollectionGeographyView(title: "Coffee origins", eyebrow: "COFFEE / GEOGRAPHY", points: bags.geographyPoints, unmappedCount: bags.count - bags.geographyPoints.count, tint: Color.coffee, symbol: "cup.and.saucer.fill", regions: RegionalAtlas.coffee) } label: { Image(systemName: "map").frame(width: 40, height: 40).background(.white.opacity(0.07), in: Circle()) }; Button { showAdd = true } label: { Label("Add", systemImage: "plus").font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(height: 40).background(Color.coffee.opacity(0.16), in: Capsule()) } }
                        ForEach(bags.filter(\.active)) { bag in CoffeeCard(bag: bag) { path.append(bag) }.contextMenu { Button("Edit bag", systemImage: "pencil") { editingBag = bag }; Button("Delete bag", systemImage: "trash", role: .destructive) { pendingDelete = bag } } }
                        InsightCard(title: "BREWING PRINCIPLE", detail: "Change one variable at a time to keep your recipes comparable.", icon: "slider.horizontal.3", tint: Color.sage)
                    }.padding(20)
                }
            }
            .navigationDestination(for: CoffeeBag.self) { BrewSetupView(bag: $bags[bags.firstIndex(of: $0) ?? 0]) }
            .sheet(isPresented: $showAdd) { AddCoffeeView { newBag in bags.insert(newBag, at: 0) } }
            .sheet(item: $editingBag) { candidate in
                if let index = bags.firstIndex(where: { $0.id == candidate.id }) { EditCoffeeView(bag: $bags[index]) }
            }
            .alert("Delete coffee bag?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete", role: .destructive) { if let pendingDelete { bags.removeAll { $0.id == pendingDelete.id } }; pendingDelete = nil }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { Text("This removes the bag and its saved details from your coffee collection.") }
            .onAppear { load() }.onChange(of: bags) { _, _ in persist() }
        }.tint(Color.starlight).preferredColorScheme(.dark)
    }
    private func load() { guard !storedBags.isEmpty else { bags = CoffeeBag.examples; return }; guard let data = storedBags.data(using: .utf8), let value = try? JSONDecoder().decode([CoffeeBag].self, from: data) else { bags = CoffeeBag.examples; return }; bags = value }
    private func persist() { if let data = try? JSONEncoder().encode(bags) { storedBags = String(decoding: data, as: UTF8.self) } }
}

private struct CoffeeCard: View {
    let bag: CoffeeBag; let action: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack(alignment: .top) { VStack(alignment: .leading, spacing: 6) { Text(bag.roaster.uppercased()).eyebrow(); Text(bag.name).font(.system(size: 30, weight: .regular, design: .serif)).fixedSize(horizontal: false, vertical: true) }; Spacer(); CoffeeThumbnail(data: bag.imageData) }; HStack { Text("\(bag.originDetail) · \(bag.process)").foregroundStyle(.secondary).font(.subheadline).lineLimit(2); Spacer(); Text("ACTIVE").statusPill(tint: Color.coffee) }; if let roastDate = bag.roastDate { Label("Roasted \(roastDate.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar").font(.caption).foregroundStyle(.secondary) }; Spacer(minLength: 6); Divider().overlay(.white.opacity(0.18)); HStack { VStack(alignment: .leading, spacing: 3) { Text("LAST RECIPE").eyebrow(); Text("\(Int(bag.lastDose))g · \(Int(bag.lastWater))g · grind \(bag.lastGrind)").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }; Spacer() }; VStack(alignment: .leading, spacing: 3) { Text("NEXT ADJUSTMENT").eyebrow(); Text(bag.lastTip).font(.caption).foregroundStyle(.primary) }; Button(action: action) { HStack { Text("Brew"); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.semibold).padding(.horizontal, 16).frame(height: 48).background(.white, in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.black) } }.padding(22).frame(minHeight: 316, alignment: .topLeading).background(LinearGradient(colors: bag.accent == "plum" ? [Color.wine.opacity(0.22), Color.coffee.opacity(0.12)] : [Color.coffee.opacity(0.24), Color.starlight.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24)).overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.09))) }
}

private struct BrewSetupView: View {
    @EnvironmentObject private var history: TastingHistoryStore
    @Binding var bag: CoffeeBag
    @State private var brewType: BrewType = .v60
    @State private var recipe: V60Recipe = .hoffmann
    @State private var dose = 20.0
    @State private var water = 320.0
    @State private var grinder: GrinderProfile = .timemore078s
    @State private var setting = GrinderProfile.timemore078s.v60Default
    @State private var temp = 200.0
    @State private var machine = ""
    @State private var shotTime = 30.0
    @State private var pressure = 9.0
    @State private var preInfusion = 5.0
    @State private var basketSize = 18.0
    @State private var tds = 0.0
    @State private var coffeeGround = false
    @State private var hotWaterReady = false
    @State private var filterReady = false
    @State private var go = false
    @State private var showEdit = false
    var ratio: String { guard dose > 0 else { return "—" }; return brewType == .espresso ? String(format: "1:%.1f", water / dose) : String(format: "%.1f:1", water / dose) }
    var extractionYield: String { guard tds > 0, dose > 0 else { return "Add TDS to calculate" }; return String(format: "%.1f%% extraction", water * (tds / 100) / dose * 100) }
    var ratioGuidance: String { brewType == .espresso ? "Starting point 1:2" : (brewType == .v60 ? "Suggested 15–17:1" : "Calculated automatically") }
    var v60Ready: Bool { coffeeGround && hotWaterReady && filterReady }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("BREW SETUP").eyebrow()
                Text(bag.name).displayTitle()
                Text("\(bag.roaster) · \(bag.origin) · \(bag.process)").supportingText()

                GroupBox("Choose a brew") {
                    Picker("Brew type", selection: $brewType) {
                        ForEach(BrewType.allCases) { type in Label(type.rawValue, systemImage: type.symbol).tag(type) }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.starlight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }.groupBoxStyle(DarkGroupBox())

                if brewType == .v60 {
                    GroupBox("V60 method") {
                        ForEach(V60Recipe.allCases) { r in
                            Button { recipe = r } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: recipe == r ? "checkmark.circle.fill" : "circle").foregroundStyle(recipe == r ? Color.coffee : .secondary)
                                    VStack(alignment: .leading) { Text(r.rawValue).fontWeight(.semibold); Text(r.caption).font(.caption).foregroundStyle(.secondary) }
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(8).background(recipe == r ? Color.coffee.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }.groupBoxStyle(DarkGroupBox())
                }

                GroupBox("Brew settings") {
                    VStack(spacing: 14) {
                        GrinderPicker(grinder: $grinder, setting: $setting, brewType: brewType)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            NumberField(title: "Dose", value: $dose, unit: "g")
                            NumberField(title: brewType.outputLabel, value: $water, unit: "g")
                            TextField("Setting", text: $setting).inputStyle("GRIND SETTING")
                            NumberField(title: "Water temp.", value: $temp, unit: "°F")
                            VStack(alignment: .leading) { Text("RATIO").eyebrow(); Text(ratio).font(.title2.monospacedDigit()); Text(ratioGuidance).font(.caption2).foregroundStyle(.secondary) }.padding(12).background(Color.sage.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }.groupBoxStyle(DarkGroupBox())

                if brewType == .espresso {
                    GroupBox("Espresso profile") {
                        VStack(spacing: 14) {
                            TextField("Machine", text: $machine).inputStyle("ESPRESSO MACHINE")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                                NumberField(title: "Shot time", value: $shotTime, unit: "seconds")
                                NumberField(title: "Peak pressure", value: $pressure, unit: "bar")
                                NumberField(title: "Pre-infusion", value: $preInfusion, unit: "seconds")
                                NumberField(title: "Basket", value: $basketSize, unit: "g")
                                NumberField(title: "TDS (optional)", value: $tds, unit: "%")
                                VStack(alignment: .leading) { Text("EXTRACTION YIELD").eyebrow(); Text(extractionYield).font(.subheadline.monospacedDigit()).foregroundStyle(tds > 0 ? Color.sage : .secondary) }.padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                            Text("Reference range · 1:2 ratio · 25–35 sec · about 9 bar. Treat these as a starting point and let taste lead.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.groupBoxStyle(DarkGroupBox())
                }

                if brewType == .v60 {
                    GroupBox("Before you begin") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A quick preflight keeps the recipe moving once the timer starts.").font(.caption).foregroundStyle(.secondary)
                            Toggle("Coffee ground", isOn: $coffeeGround)
                            Toggle("Hot water ready", isOn: $hotWaterReady)
                            Toggle("Filter rinsed & brewer ready", isOn: $filterReady)
                        }
                        .tint(Color.sage)
                    }.groupBoxStyle(DarkGroupBox())
                }

                TastingHistoryCard(productID: bag.id, tint: Color.coffee)

                NavigationLink { PalateProfileView(request: .coffee(bag, records: history.records(for: bag.id)), tint: Color.coffee) } label: {
                    HStack { Label("Ask Palate", systemImage: "sparkles"); Spacer(); Image(systemName: "arrow.right") }
                        .fontWeight(.bold).padding().frame(maxWidth: .infinity)
                        .background(Color.coffee.opacity(0.17), in: RoundedRectangle(cornerRadius: 14))
                }

                Button { bag.lastDose = dose; bag.lastWater = water; bag.lastGrind = setting; go = true } label: {
                    HStack { Text(brewType == .v60 ? "Start guided brew" : "Continue to tasting"); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.starlight, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                }
                .disabled(brewType == .v60 && !v60Ready)
                .opacity(brewType == .v60 && !v60Ready ? 0.45 : 1)
            }.padding(20)
        }
        .background(Color.space)
        .onChange(of: brewType) { _, type in
            dose = type.defaultDose; water = type.defaultOutput; temp = type.defaultTemperature
            setting = type == .espresso ? (grinder.espressoDefault ?? grinder.v60Default) : grinder.v60Default
        }
        .navigationDestination(isPresented: $go) {
            if brewType == .v60 { GuidedBrewView(bag: bag, recipe: recipe, dose: dose, water: water, grinder: grinder.rawValue, setting: setting) }
            else if brewType == .espresso { EspressoTimerView(bag: bag, dose: dose, yield: water, grinder: grinder.rawValue, setting: setting, suggestedShotTime: Int(shotTime)) }
            else { TasteView(bag: bag, dose: dose, water: water, grinder: grinder.rawValue, setting: setting) }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }
        .sheet(isPresented: $showEdit) { EditCoffeeView(bag: $bag) }
        .preferredColorScheme(.dark)
    }
}

private struct GuidedBrewView: View {
    let bag: CoffeeBag, recipe: V60Recipe, dose: Double, water: Double, grinder, setting: String
    @State private var stage = 0
    @State private var seconds = 0
    @State private var totalSeconds = 0
    @State private var running = true
    @State private var goTaste = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var current: BrewStage { recipe.stages[min(stage, recipe.stages.count - 1)] }
    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle().stroke(Color.coffee.opacity(0.38), lineWidth: 1).frame(width: 330, height: 330).rotationEffect(.degrees(Double(seconds) * 3))
                Circle().fill(Color.coffee.opacity(0.09)).frame(width: 270, height: 270)
                VStack(spacing: 8) {
                    Text(current.name.uppercased()).eyebrow()
                    Text(time(isDrawdown ? totalSeconds : current.seconds - seconds)).font(.system(size: 58, weight: .regular, design: .serif)).monospacedDigit()
                    Text(current.instruction).fontDesign(.serif).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2).padding(.horizontal, 34)
                    if PourMotionGuide.supports(current.technique) {
                        PourMotionGuide(technique: current.technique)
                            .id(current.technique)
                            .frame(height: 62)
                            .padding(.top, 2)
                    }
                }
            }
            .overlay(alignment: .top) { Image(systemName: "drop.fill").foregroundStyle(Color.sage).offset(y: -11) }
            HStack { Stat(title: "Total brew", value: time(totalSeconds)); Stat(title: "Target", value: "\(current.weight) g"); Stat(title: "Method", value: current.technique) }
            if isDrawdown {
                VStack(spacing: 10) {
                    Text("The timer includes every brew stage. Stop when the bed is dry; you can correct the total in the tasting log.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Stop brew") {
                        running = false
                        goTaste = true
                    }
                    .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
                }
            } else {
                HStack { Button("Skip step") { advance() }.buttonStyle(.bordered); Button(running ? "Pause" : "Resume") { running.toggle() }.buttonStyle(.borderedProminent) }.controlSize(.large)
            }
            Spacer()
        }
        .padding(24)
        .background(Color.space)
        .onReceive(timer) { _ in
            guard running else { return }
            totalSeconds += 1
            seconds += 1
            if !isDrawdown && seconds >= current.seconds { advance() }
        }
        .navigationDestination(isPresented: $goTaste) { TasteView(bag: bag, dose: dose, water: water, grinder: grinder, setting: setting, timingLabel: "Total brew", timingSeconds: totalSeconds) }
        .preferredColorScheme(.dark)
    }
    var isDrawdown: Bool { current.name.localizedCaseInsensitiveContains("drawdown") }
    func advance() { UINotificationFeedbackGenerator().notificationOccurred(.success); seconds = 0; stage += 1; if stage >= recipe.stages.count { running = false; goTaste = true } }
    func time(_ n: Int) -> String { String(format: "%d:%02d", max(0,n)/60, max(0,n)%60) }
}

private struct PourMotionGuide: View {
    private enum Style { case smallCircle, largeCircle, center }
    let technique: String
    @State private var progress: CGFloat = 0

    private var style: Style {
        if technique.localizedCaseInsensitiveContains("small") { return .smallCircle }
        if technique.localizedCaseInsensitiveContains("center") { return .center }
        return .largeCircle
    }

    static func supports(_ technique: String) -> Bool {
        !technique.localizedCaseInsensitiveContains("wait")
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(style == .center ? "POUR PATH · CENTER" : "POUR PATH · \(style == .smallCircle ? "SMALL" : "LARGE") CIRCLES")
                .font(.caption2.weight(.bold)).tracking(1.1).foregroundStyle(Color.starlight)
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                let radius = style == .smallCircle ? size * 0.22 : size * 0.38
                let phase = progress * .pi * 2 - (.pi / 2)
                ZStack {
                    if style == .center {
                        Capsule().fill(.white.opacity(0.14)).frame(width: 2, height: size * 0.72)
                        Capsule().fill(LinearGradient(colors: [Color.coffee.opacity(0), Color.coffee.opacity(0.86)], startPoint: .top, endPoint: .bottom)).frame(width: 4, height: size * 0.26).offset(y: (-size * 0.36) + (size * 0.72 * progress))
                        Circle().fill(Color.starlight).frame(width: 9, height: 9).shadow(color: Color.starlight.opacity(0.65), radius: 5).offset(y: (-size * 0.36) + (size * 0.72 * progress))
                    } else {
                        Circle().stroke(.white.opacity(0.12), lineWidth: 1).frame(width: size * 0.78, height: size * 0.78)
                        Circle().stroke(.white.opacity(0.12), lineWidth: 1).frame(width: size * 0.44, height: size * 0.44)
                        Circle().trim(from: max(0, progress - 0.26), to: progress).stroke(Color.coffee, style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: radius * 2, height: radius * 2).rotationEffect(.degrees(-90))
                        Circle().fill(Color.starlight).frame(width: 9, height: 9).shadow(color: Color.starlight.opacity(0.65), radius: 5).offset(x: cos(phase) * radius, y: sin(phase) * radius)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { progress = 1 } }
    }
}

private struct TasteView: View {
    let bag: CoffeeBag, dose, water: Double, grinder, setting: String
    let timingLabel: String?
    let timingSeconds: Int?
    let choices = ["Sour", "Bitter", "Balanced", "Weak", "Strong", "Sweet", "Fruity", "Floral"]
    init(bag: CoffeeBag, dose: Double, water: Double, grinder: String, setting: String, timingLabel: String? = nil, timingSeconds: Int? = nil) {
        self.bag = bag; self.dose = dose; self.water = water; self.grinder = grinder; self.setting = setting; self.timingLabel = timingLabel; self.timingSeconds = timingSeconds
    }
    var body: some View {
        GuidedTastingLog(
            category: .coffee,
            productID: bag.id,
            product: bag.name,
            producer: bag.roaster,
            title: "Log this cup",
            eyebrow: "COFFEE / TASTING NOTE",
            choices: choices,
            tint: Color.coffee,
            contextPrompt: "How did you brew it?",
            initialContext: "\(Int(dose))g coffee · \(Int(water))g water · \(grinder) \(setting)\(timingText)",
            savedMessage: "Saved to your coffee history.",
            measurementLabel: timingLabel,
            measurementSeconds: timingSeconds,
            destination: AnyView(CoffeeShelfView())
        )
    }
    private var timingText: String { guard let timingLabel, let timingSeconds else { return "" }; return " · \(timingLabel) \(time(timingSeconds))" }
    private func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}

private struct EspressoTimerView: View {
    let bag: CoffeeBag
    let dose, yield: Double
    let grinder, setting: String
    let suggestedShotTime: Int
    @State private var seconds = 0
    @State private var running = false
    @State private var finished = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            Text("ESPRESSO / EXTRACTION").eyebrow().foregroundStyle(Color.coffee)
            Text("Time the shot").displayTitle()
            Text("Start with the pump. Stop when your target yield is reached; this timing will travel with your tasting note.").supportingText().multilineTextAlignment(.center)
            ZStack {
                Circle().stroke(Color.coffee.opacity(0.35), lineWidth: 2).frame(width: 272, height: 272)
                VStack(spacing: 8) {
                    Text(time(seconds)).font(.system(size: 62, weight: .regular, design: .serif)).monospacedDigit()
                    Text("Suggested: \(suggestedShotTime) sec").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(running ? "Stop extraction" : (seconds == 0 ? "Start extraction" : "Resume extraction")) { running.toggle() }
                .buttonStyle(.borderedProminent).tint(running ? .red : Color.coffee).controlSize(.large)
            if !running && seconds > 0 {
                Button("Use \(time(seconds)) and continue") { finished = true }.buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding(24).background(Color.space)
        .onReceive(timer) { _ in if running { seconds += 1 } }
        .navigationDestination(isPresented: $finished) { TasteView(bag: bag, dose: dose, water: yield, grinder: grinder, setting: setting, timingLabel: "Extraction", timingSeconds: seconds) }
        .preferredColorScheme(.dark)
    }

    private func time(_ value: Int) -> String { String(format: "%d:%02d", value / 60, value % 60) }
}

private struct RecommendationView: View { let title, copy: String; let bag: CoffeeBag; var body: some View { VStack(alignment: .leading, spacing: 22) { Spacer(); HStack(spacing: 16) { Image("PalateMark").resizable().scaledToFit().frame(width: 46, height: 46); Image(systemName: "checkmark").font(.title2).foregroundStyle(Color.sage).frame(width: 46, height: 46).overlay(Circle().stroke(Color.sage)) }; Text("BREW SAVED").eyebrow(); Text("Tasting recorded").displayTitle(); Text(bag.name).supportingText(); VStack(alignment: .leading, spacing: 10) { Text("NEXT BREW").eyebrow(); Text(title).font(.title2).fontDesign(.serif); Text(copy).supportingText() }.padding(20).background(Color.coffee.opacity(0.1), in: RoundedRectangle(cornerRadius: 18)); Spacer(); NavigationLink { CoffeeShelfView() } label: { HStack { Text("Back to coffee"); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.starlight, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black) } }.padding(24).background(Color.space).preferredColorScheme(.dark).navigationBarBackButtonHidden() } }

private struct AddCoffeeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var roaster = "Olympia Coffee"; @State private var origin = ""; @State private var estate = ""; @State private var county = ""; @State private var process = ""; @State private var notes = ""
    @State private var roastDate = Date(); @State private var imageData: Data?
    let save: (CoffeeBag) -> Void

    var body: some View { NavigationStack { Form {
        Section("Bag photo") {
            LabelScanControl(kind: .coffee, imageData: $imageData) { scan in
                if let value = scan.value("Roaster") { roaster = value }
                if let value = scan.value("Coffee name") { name = value }
                if let value = scan.value("Origin") { origin = value }
                if let value = scan.value("Process") { process = value }
                if let value = scan.date("Roast date") { roastDate = value }
            }
            Text("Capture the full front label in even light. Review detected details before applying them.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Bag details") {
            TextField("Roaster", text: $roaster); TextField("Coffee name", text: $name); DatePicker("Roast date", selection: $roastDate, displayedComponents: .date); TextField("Origin country / region", text: $origin); TextField("Estate or farm (optional)", text: $estate); TextField("County or subregion (optional)", text: $county); TextField("Process", text: $process); TextField("Roaster notes, comma separated", text: $notes)
        }
    }.navigationTitle("Add coffee").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Add") { guard !name.isEmpty else { return }; save(CoffeeBag(name: name, roaster: roaster, origin: origin, process: process, notes: notes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }, accent: "indigo", estate: estate.nilIfBlank, county: county.nilIfBlank, roastDate: roastDate, imageData: imageData)); dismiss() } } } }.preferredColorScheme(.dark) } }

private struct EditCoffeeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bag: CoffeeBag
    @State private var draft: CoffeeBag
    @State private var notes = ""

    init(bag: Binding<CoffeeBag>) {
        _bag = bag
        _draft = State(initialValue: bag.wrappedValue)
        _notes = State(initialValue: bag.wrappedValue.notes.joined(separator: ", "))
    }

    private var roastDate: Binding<Date> {
        Binding(get: { draft.roastDate ?? Date() }, set: { draft.roastDate = $0 })
    }
    private var estate: Binding<String> { Binding(get: { draft.estate ?? "" }, set: { draft.estate = $0.nilIfBlank }) }
    private var county: Binding<String> { Binding(get: { draft.county ?? "" }, set: { draft.county = $0.nilIfBlank }) }

    var body: some View { NavigationStack { Form {
        Section("Bag photo") {
            LabelScanControl(kind: .coffee, imageData: $draft.imageData) { scan in
                if let value = scan.value("Roaster") { draft.roaster = value }
                if let value = scan.value("Coffee name") { draft.name = value }
                if let value = scan.value("Origin") { draft.origin = value }
                if let value = scan.value("Process") { draft.process = value }
                if let value = scan.date("Roast date") { draft.roastDate = value }
            }
            if draft.imageData != nil { Button("Remove photo", role: .destructive) { draft.imageData = nil } }
        }
        Section("Bag details") {
            TextField("Roaster", text: $draft.roaster); TextField("Coffee name", text: $draft.name); DatePicker("Roast date", selection: roastDate, displayedComponents: .date); TextField("Origin country / region", text: $draft.origin); TextField("Estate or farm (optional)", text: estate); TextField("County or subregion (optional)", text: county); TextField("Process", text: $draft.process); TextField("Roaster notes, comma separated", text: $notes)
        }
    }
    .navigationTitle("Edit coffee")
    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Done") { draft.notes = notes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }; bag = draft; dismiss() } } }
    }.preferredColorScheme(.dark) }
}

private struct CoffeeThumbnail: View {
    let data: Data?
    var body: some View { Group { if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() } else { Image(systemName: "cup.and.saucer.fill").foregroundStyle(Color.coffee.opacity(0.85)).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.coffee.opacity(0.12)) } }.frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 12)) }
}

private struct GrinderPicker: View {
    @Binding var grinder: GrinderProfile
    @Binding var setting: String
    let brewType: BrewType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GRINDER").eyebrow()
            Picker("Grinder", selection: $grinder) {
                ForEach(GrinderProfile.allCases) { profile in
                    VStack(alignment: .leading) { Text(profile.rawValue); Text(profile.defaultSummary).font(.caption) }.tag(profile)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("Defaults · \(grinder.defaultSummary)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: grinder) { _, newValue in setting = brewType == .espresso ? (newValue.espressoDefault ?? newValue.v60Default) : newValue.v60Default }
    }
}

private struct NumberField: View { let title: String; @Binding var value: Double; let unit: String; var body: some View { VStack(alignment: .leading) { Text(title.uppercased()).eyebrow(); TextField(title, value: $value, format: .number).keyboardType(.decimalPad).font(.title3); Text(unit).font(.caption2).foregroundStyle(.secondary) }.padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)) } }
private struct Stat: View { let title, value: String; var body: some View { VStack(alignment: .leading) { Text(title.uppercased()).eyebrow(); Text(value).font(.headline.monospacedDigit()) }.frame(maxWidth: .infinity, alignment: .leading) } }
private struct DarkGroupBox: GroupBoxStyle { func makeBody(configuration: Configuration) -> some View { VStack(alignment: .leading, spacing: 14) { configuration.label.font(.caption.weight(.bold)).foregroundStyle(Color.starlight); configuration.content }.padding(16).background(Color.surface, in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.steel)) } }
private struct FlowLayout<T: Hashable, Content: View>: View { let items: [T]; let content: (T) -> Content; init(items: [T], @ViewBuilder content: @escaping (T) -> Content) { self.items = items; self.content = content }; var body: some View { LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 8)], alignment: .leading, spacing: 8) { ForEach(items, id: \.self) { content($0) } } } }
private extension View { func eyebrow() -> some View { self.font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(Color.starlight) }; func displayTitle() -> some View { self.font(.system(size: 42, weight: .regular, design: .serif)).tracking(-1.1) }; func serifMuted() -> some View { self.font(.body.italic()).fontDesign(.serif).foregroundStyle(.secondary) }; func supportingText() -> some View { self.font(.subheadline).foregroundStyle(.secondary) }; func statusPill(tint: Color) -> some View { self.font(.caption2.weight(.bold)).tracking(1).foregroundStyle(tint).padding(.horizontal, 9).padding(.vertical, 6).background(tint.opacity(0.15), in: Capsule()) }; func inputStyle(_ label: String) -> some View { VStack(alignment: .leading) { Text(label).eyebrow(); self.font(.title3) }.padding(12).background(Color.surface, in: RoundedRectangle(cornerRadius: 12)) } }
private extension String { var nilIfBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self } }
extension Color {
    static let space = Color(red: 8/255, green: 11/255, blue: 18/255)
    static let surface = Color(red: 21/255, green: 26/255, blue: 36/255)
    static let ivory = Color(red: 244/255, green: 240/255, blue: 232/255)
    static let starlight = Color(red: 216/255, green: 181/255, blue: 106/255)
    static let coffee = Color(red: 199/255, green: 137/255, blue: 91/255)
    static let wine = Color(red: 201/255, green: 104/255, blue: 130/255)
    static let scotch = Color(red: 217/255, green: 154/255, blue: 69/255)
    static let sage = Color(red: 121/255, green: 185/255, blue: 154/255)
    static let steel = Color(red: 43/255, green: 51/255, blue: 64/255)
}

// MARK: - Wine

private struct WineShelfView: View {
    @AppStorage("wineBottles") private var stored = ""
    @State private var bottles: [WineBottle] = []
    @State private var showAdd = false
    @State private var pendingDelete: WineBottle?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.space.ignoresSafeArea()
                LinearGradient(colors: [Color.wine.opacity(0.16), .clear, Color.starlight.opacity(0.06)], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ModuleHeader(kicker: "WINE", title: "Your cellar", detail: "\(bottles.count) bottles · origin, style, and tasting history", symbol: "wineglass.fill", tint: Color.wine)
                        HStack { Text("BOTTLES").eyebrow(); Spacer(); NavigationLink { CollectionGeographyView(title: "Wine regions", eyebrow: "WINE / GEOGRAPHY", points: bottles.geographyPoints, unmappedCount: bottles.count - bottles.geographyPoints.count, tint: Color.wine, symbol: "wineglass.fill", regions: RegionalAtlas.wine) } label: { Image(systemName: "map").frame(width: 40, height: 40).background(.white.opacity(0.07), in: Circle()) }; Button { showAdd = true } label: { Label("Add", systemImage: "plus").font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(height: 40).background(Color.wine.opacity(0.15), in: Capsule()) } }
                        ForEach($bottles) { $bottle in NavigationLink { WineDetailView(bottle: $bottle) } label: { WineCard(bottle: bottle) }.buttonStyle(.plain).contextMenu { Button("Delete bottle", systemImage: "trash", role: .destructive) { pendingDelete = bottle } } }
                        InsightCard(title: "COLLECTION INSIGHT", detail: "Explore bottles by country, region, grape, or producer as your collection grows.", icon: "location.north.line", tint: Color.wine)
                    }.padding(20)
                }
            }
            .sheet(isPresented: $showAdd) { AddWineView { bottles.insert($0, at: 0) } }
            .alert("Delete wine bottle?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete", role: .destructive) { if let pendingDelete { bottles.removeAll { $0.id == pendingDelete.id } }; pendingDelete = nil }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { Text("This removes the bottle and its saved details from your cellar.") }
            .onAppear { load() }.onChange(of: bottles) { _, _ in save() }
        }
    }
    private func load() { guard !stored.isEmpty else { bottles = WineBottle.examples; return }; guard let data = stored.data(using: .utf8), let decoded = try? JSONDecoder().decode([WineBottle].self, from: data) else { bottles = WineBottle.examples; return }; bottles = decoded }
    private func save() { if let data = try? JSONEncoder().encode(bottles) { stored = String(decoding: data, as: UTF8.self) } }
}

private struct WineCard: View {
    let bottle: WineBottle
    var body: some View { VStack(alignment: .leading, spacing: 13) { HStack { Text(bottle.producer.uppercased()).eyebrow().foregroundStyle(Color.wine); Spacer(); Text(bottle.vintage).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }; Text(bottle.name).font(.system(size: 29, weight: .regular, design: .serif)); Text("\(bottle.grapes) · \(bottle.region)").font(.subheadline).foregroundStyle(.secondary); Divider().overlay(.white.opacity(0.15)); HStack { Label(bottle.country, systemImage: "mappin.and.ellipse"); Spacer(); Image(systemName: "arrow.up.right") }.font(.caption).foregroundStyle(Color.wine) }.padding(20).background(LinearGradient(colors: [Color.wine.opacity(0.22), Color.starlight.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22)) }
}

private struct WineDetailView: View {
    @EnvironmentObject private var history: TastingHistoryStore
    @Binding var bottle: WineBottle
    @State private var mapPosition: MapCameraPosition
    @State private var showTaste = false
    @State private var showEdit = false
    init(bottle: Binding<WineBottle>) { _bottle = bottle; let value = bottle.wrappedValue; _mapPosition = State(initialValue: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: value.latitude, longitude: value.longitude), span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 9)))) }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { Text("WINE / BOTTLE").eyebrow().foregroundStyle(Color.wine); Text(bottle.name).displayTitle(); Text("\(bottle.producer) · \(bottle.vintage)").supportingText(); provenanceMap(title: bottle.region, subtitle: "\(bottle.country) · Explore origin", tint: Color.wine); GroupBox("Details") { DetailGrid(items: [("GRAPE", bottle.grapes), ("REGION", bottle.region), ("VINTAGE", bottle.vintage)]) }.groupBoxStyle(DarkGroupBox()); GroupBox("Producer notes") { FlowLayout(items: bottle.notes) { Text($0).padding(9).background(Color.wine.opacity(0.13), in: Capsule()) } }.groupBoxStyle(DarkGroupBox()); TastingHistoryCard(productID: bottle.id, tint: Color.wine); NavigationLink { PalateProfileView(request: .wine(bottle, records: history.records(for: bottle.id)), tint: Color.wine) } label: { HStack { Label("Ask Palate", systemImage: "sparkles"); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.wine.opacity(0.18), in: RoundedRectangle(cornerRadius: 14)) }; Button { showTaste = true } label: { HStack { Text("Log tasting"); Spacer(); Image(systemName: "wineglass.fill") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.wine, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black) } }.padding(20) }.background(Color.space).navigationDestination(isPresented: $showTaste) { WineTastingView(bottle: bottle) }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }.sheet(isPresented: $showEdit) { EditWineView(bottle: $bottle) }.preferredColorScheme(.dark) }
    @ViewBuilder private func provenanceMap(title: String, subtitle: String, tint: Color) -> some View { VStack(alignment: .leading, spacing: 0) { Map(position: $mapPosition) { Marker(title, coordinate: CLLocationCoordinate2D(latitude: bottle.latitude, longitude: bottle.longitude)).tint(tint) }.frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 18)); VStack(alignment: .leading, spacing: 3) { Text("ORIGIN").eyebrow().foregroundStyle(tint); Text(title).font(.title3.weight(.medium)); Text(subtitle).font(.caption).foregroundStyle(.secondary) }.padding(15) }.background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18)) }
}

private struct WineTastingView: View {
    let bottle: WineBottle
    let choices = ["Light", "Structured", "Fresh", "Earthy", "Fruit-forward", "Silky", "Tannic", "Long finish"]
    var body: some View {
        GuidedTastingLog(category: .wine, productID: bottle.id, product: bottle.name, producer: bottle.producer, title: "Log this pour", eyebrow: "WINE / TASTING NOTE", choices: choices, tint: Color.wine, contextPrompt: "Where or with what are you tasting?", initialContext: "", savedMessage: "Saved to your cellar history.", measurementLabel: nil, measurementSeconds: nil, destination: AnyView(WineShelfView()))
    }
}

// MARK: - Scotch

private struct ScotchShelfView: View {
    @AppStorage("scotchBottles") private var stored = ""; @State private var bottles: [ScotchBottle] = []; @State private var showAdd = false; @State private var pendingDelete: ScotchBottle?
    var body: some View { NavigationStack { ZStack { Color.space.ignoresSafeArea(); LinearGradient(colors: [Color.scotch.opacity(0.16), .clear, Color.starlight.opacity(0.06)], startPoint: .topTrailing, endPoint: .bottomLeading).ignoresSafeArea(); ScrollView { VStack(alignment: .leading, spacing: 22) { ModuleHeader(kicker: "SCOTCH", title: "Your cabinet", detail: "\(bottles.count) bottles · distillery, cask, and tasting history", symbol: "flame.fill", tint: Color.scotch); HStack { Text("BOTTLES").eyebrow(); Spacer(); NavigationLink { CollectionGeographyView(title: "Scotch regions", eyebrow: "SCOTCH / GEOGRAPHY", points: bottles.geographyPoints, unmappedCount: bottles.count - bottles.geographyPoints.count, tint: Color.scotch, symbol: "flame.fill", regions: RegionalAtlas.scotch) } label: { Image(systemName: "map").frame(width: 40, height: 40).background(.white.opacity(0.07), in: Circle()) }; Button { showAdd = true } label: { Label("Add", systemImage: "plus").font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(height: 40).background(Color.scotch.opacity(0.15), in: Capsule()) } }; ForEach($bottles) { $bottle in NavigationLink { ScotchDetailView(bottle: $bottle) } label: { ScotchCard(bottle: bottle) }.buttonStyle(.plain).contextMenu { Button("Delete bottle", systemImage: "trash", role: .destructive) { pendingDelete = bottle } } }; InsightCard(title: "COLLECTION INSIGHT", detail: "Your tasting history will surface patterns across distilleries, regions, casks, and peat levels.", icon: "sparkles", tint: Color.scotch) }.padding(20) } }.sheet(isPresented: $showAdd) { AddScotchView { bottles.insert($0, at: 0) } }.alert("Delete Scotch bottle?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) { Button("Delete", role: .destructive) { if let pendingDelete { bottles.removeAll { $0.id == pendingDelete.id } }; pendingDelete = nil }; Button("Cancel", role: .cancel) { pendingDelete = nil } } message: { Text("This removes the bottle and its saved details from your cabinet.") }.onAppear { load() }.onChange(of: bottles) { _, _ in save() } } }
    private func load() { guard !stored.isEmpty else { bottles = ScotchBottle.examples; return }; guard let data = stored.data(using: .utf8), let decoded = try? JSONDecoder().decode([ScotchBottle].self, from: data) else { bottles = ScotchBottle.examples; return }; bottles = decoded }
    private func save() { if let data = try? JSONEncoder().encode(bottles) { stored = String(decoding: data, as: UTF8.self) } }
}

private struct ScotchCard: View { let bottle: ScotchBottle; var body: some View { VStack(alignment: .leading, spacing: 13) { HStack { Text(bottle.distillery.uppercased()).eyebrow().foregroundStyle(Color.scotch); Spacer(); Text(bottle.ageStatement).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }; Text(bottle.name).font(.system(size: 29, weight: .regular, design: .serif)); Text("\(bottle.region) · \(bottle.cask)").font(.subheadline).foregroundStyle(.secondary); Divider().overlay(.white.opacity(0.15)); HStack { Label(bottle.abv, systemImage: "drop.fill"); Spacer(); Image(systemName: "arrow.up.right") }.font(.caption).foregroundStyle(Color.scotch) }.padding(20).background(LinearGradient(colors: [Color.scotch.opacity(0.24), .brown.opacity(0.17)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22)) } }

private struct ScotchDetailView: View {
    @EnvironmentObject private var history: TastingHistoryStore
    @Binding var bottle: ScotchBottle; @State private var mapPosition: MapCameraPosition; @State private var showTaste = false; @State private var showEdit = false
    init(bottle: Binding<ScotchBottle>) { _bottle = bottle; let value = bottle.wrappedValue; _mapPosition = State(initialValue: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: value.latitude, longitude: value.longitude), span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)))) }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { Text("SCOTCH / BOTTLE").eyebrow().foregroundStyle(Color.scotch); Text(bottle.name).displayTitle(); Text("\(bottle.distillery) · \(bottle.ageStatement) · \(bottle.abv)").supportingText(); VStack(alignment: .leading, spacing: 0) { Map(position: $mapPosition) { Marker(bottle.region, coordinate: CLLocationCoordinate2D(latitude: bottle.latitude, longitude: bottle.longitude)).tint(Color.scotch) }.frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 18)); VStack(alignment: .leading, spacing: 3) { Text("DISTILLERY ORIGIN").eyebrow().foregroundStyle(Color.scotch); Text(bottle.region).font(.title3.weight(.medium)); Text("Scotland · Explore origin").font(.caption).foregroundStyle(.secondary) }.padding(15) }.background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18)); GroupBox("Details") { DetailGrid(items: [("CASK", bottle.cask), ("REGION", bottle.region), ("STRENGTH", bottle.abv)]) }.groupBoxStyle(DarkGroupBox()); GroupBox("Distillery notes") { FlowLayout(items: bottle.notes) { Text($0).padding(9).background(Color.scotch.opacity(0.13), in: Capsule()) } }.groupBoxStyle(DarkGroupBox()); TastingHistoryCard(productID: bottle.id, tint: Color.scotch); NavigationLink { PalateProfileView(request: .scotch(bottle, records: history.records(for: bottle.id)), tint: Color.scotch) } label: { HStack { Label("Ask Palate", systemImage: "sparkles"); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.scotch.opacity(0.18), in: RoundedRectangle(cornerRadius: 14)) }; Button { showTaste = true } label: { HStack { Text("Log tasting"); Spacer(); Image(systemName: "flame.fill") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(Color.scotch, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black) } }.padding(20) }.background(Color.space).navigationDestination(isPresented: $showTaste) { ScotchTastingView(bottle: bottle) }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { showEdit = true } } }.sheet(isPresented: $showEdit) { EditScotchView(bottle: $bottle) }.preferredColorScheme(.dark) }
}

private struct ScotchTastingView: View {
    let bottle: ScotchBottle
    let choices = ["Honeyed", "Sherried", "Smoky", "Maritime", "Oily", "Spiced", "Dry", "Long finish"]
    var body: some View {
        GuidedTastingLog(category: .scotch, productID: bottle.id, product: bottle.name, producer: bottle.distillery, title: "Log this dram", eyebrow: "SCOTCH / TASTING NOTE", choices: choices, tint: Color.scotch, contextPrompt: "How are you drinking it?", initialContext: "Neat", savedMessage: "Saved to your cabinet history.", measurementLabel: nil, measurementSeconds: nil, destination: AnyView(ScotchShelfView()))
    }
}

// MARK: - Shared tasting UI

private struct AppBrand: View { let actionSymbol: String; var body: some View { HStack { Image("PalateMark").resizable().scaledToFit().frame(width: 30, height: 30).accessibilityLabel("Palate"); Text("PALATE").font(.caption.weight(.bold)).tracking(3); Spacer(); Image(systemName: actionSymbol).font(.subheadline).foregroundStyle(.secondary).frame(width: 36, height: 36).background(.white.opacity(0.06), in: Circle()) } } }
private struct ModuleHeader: View { let kicker, title, detail, symbol: String; let tint: Color; var body: some View { VStack(alignment: .leading, spacing: 10) { AppBrand(actionSymbol: symbol); Text(kicker).eyebrow().foregroundStyle(tint); Text(title).displayTitle(); Text(detail).supportingText() } } }
private struct InsightCard: View { let title, detail, icon: String; let tint: Color; var body: some View { HStack(alignment: .top, spacing: 14) { Image(systemName: icon).foregroundStyle(tint).frame(width: 22, height: 22).background(tint.opacity(0.13), in: Circle()); VStack(alignment: .leading, spacing: 5) { Text(title).eyebrow().foregroundStyle(tint); Text(detail).font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true) } }.padding(17).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18)).overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.08))) } }
private struct DetailGrid: View { let items: [(String, String)]; var body: some View { LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 15) { ForEach(items, id: \.0) { item in VStack(alignment: .leading, spacing: 4) { Text(item.0).eyebrow(); Text(item.1).font(.subheadline).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading) } } } }

private struct GuidedTastingLog: View {
    @EnvironmentObject private var history: TastingHistoryStore
    let category: TastingCategory
    let productID: UUID
    let product, producer, title, eyebrow: String
    let choices: [String]
    let tint: Color
    let contextPrompt, initialContext, savedMessage: String
    let measurementLabel: String?
    let measurementSeconds: Int?
    let destination: AnyView

    @State private var step = 0
    @State private var context = ""
    @State private var selected: Set<String> = []
    @State private var rating = 0
    @State private var note = ""
    @State private var measuredSeconds = 0
    @State private var saved = false

    private var stepTitle: String { ["Set the scene", "What stood out?", "Make it memorable"][step] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(eyebrow).eyebrow().foregroundStyle(tint)
                Text(title).displayTitle()
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule().fill(index <= step ? tint : .white.opacity(0.13)).frame(height: 4)
                    }
                }
                Text("STEP \(step + 1) OF 3 · \(stepTitle.uppercased())").eyebrow().foregroundStyle(tint)

                GroupBox(stepTitle) {
                    if step == 0 {
                        Text("A little context makes this tasting easier to revisit later.").supportingText()
                        if let measurementLabel {
                            Stepper(value: $measuredSeconds, in: 0...900, step: 1) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(measurementLabel) time").font(.subheadline.weight(.semibold))
                                    Text(measuredSeconds > 0 ? time(measuredSeconds) : "Not recorded").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .tint(tint)
                        }
                        TextField(contextPrompt, text: $context, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                    } else if step == 1 {
                        Text("Choose every descriptor that feels true. There is no required number.").supportingText()
                        FlowLayout(items: choices) { choice in
                            Button(choice) { toggle(choice) }
                                .padding(.horizontal, 13).padding(.vertical, 9)
                                .background(selected.contains(choice) ? tint : .white.opacity(0.07), in: Capsule())
                                .foregroundStyle(selected.contains(choice) ? .black : .primary)
                        }
                    } else {
                        Text("How much would you want to return to this? Add a thought for your future self.").supportingText()
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { value in
                                Button { rating = value } label: {
                                    Image(systemName: value <= rating ? "star.fill" : "star")
                                        .font(.title2).foregroundStyle(value <= rating ? tint : .secondary)
                                }.accessibilityLabel("\(value) star rating")
                            }
                        }.padding(.vertical, 4)
                        TextField("A detail worth remembering", text: $note, axis: .vertical)
                            .lineLimit(3...6).textFieldStyle(.roundedBorder)
                    }
                }
                .groupBoxStyle(DarkGroupBox())

                Button { advance() } label: {
                    HStack { Text(step == 2 ? "Save tasting" : "Continue"); Spacer(); Image(systemName: step == 2 ? "checkmark" : "arrow.right") }
                        .fontWeight(.bold).padding().frame(maxWidth: .infinity)
                        .background(tint, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black)
                }
            }
            .padding(20)
        }
        .background(Color.space)
        .onAppear { if context.isEmpty { context = initialContext }; if let measurementSeconds { measuredSeconds = measurementSeconds } }
        .navigationDestination(isPresented: $saved) {
            TastingSavedView(product: product, message: savedMessage, tint: tint, destination: destination)
        }
        .preferredColorScheme(.dark)
    }

    private func toggle(_ choice: String) {
        if selected.contains(choice) { selected.remove(choice) } else { selected.insert(choice) }
    }

    private func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }

    private func advance() {
        guard step < 2 else {
            history.add(TastingRecord(category: category, productID: productID, productName: product, producerName: producer, context: context, measurementLabel: measurementLabel, measurementSeconds: measuredSeconds > 0 ? measuredSeconds : nil, descriptors: selected.sorted(), rating: rating, note: note))
            saved = true
            return
        }
        withAnimation { step += 1 }
    }
}

private struct TastingHistoryCard: View {
    @EnvironmentObject private var history: TastingHistoryStore
    let productID: UUID
    let tint: Color

    private var records: [TastingRecord] { history.records(for: productID) }

    var body: some View {
        GroupBox("Tasting history") {
            if records.isEmpty {
                Label("Your saved tastings will appear here.", systemImage: "clock")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(records.prefix(3)) { record in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(record.date.formatted(date: .abbreviated, time: .omitted)).font(.caption.weight(.semibold))
                                Spacer()
                                if record.rating > 0 { Text(String(repeating: "★", count: record.rating)).font(.caption).foregroundStyle(tint) }
                            }
                            if !record.descriptors.isEmpty { Text(record.descriptors.joined(separator: " · ")).font(.subheadline.weight(.medium)) }
                            if let label = record.measurementLabel, let seconds = record.measurementSeconds { Label("\(label): \(time(seconds))", systemImage: "timer").font(.caption.weight(.medium)).foregroundStyle(tint) }
                            if !record.context.isEmpty { Text(record.context).font(.caption).foregroundStyle(.secondary) }
                            if record.hasNote { Text(record.note).font(.caption).foregroundStyle(.secondary).italic() }
                        }
                        if record.id != records.prefix(3).last?.id { Divider().overlay(.white.opacity(0.12)) }
                    }
                    if records.count > 3 { Text("\(records.count - 3) earlier tastings saved").font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .groupBoxStyle(DarkGroupBox())
    }
    private func time(_ seconds: Int) -> String { String(format: "%d:%02d", seconds / 60, seconds % 60) }
}

private struct PalateProfileView: View {
    let request: PalateProfileRequest
    let tint: Color
    @State private var profile: PalateProfile?
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("PALATE INTELLIGENCE").eyebrow().foregroundStyle(tint)
                Text("Meet your\nbeverage.").displayTitle()
                Text("A guided perspective built from this item’s details and your saved tasting history.").supportingText()

                if isLoading {
                    VStack(spacing: 14) { ProgressView().tint(tint); Text("Building your profile…").font(.subheadline).foregroundStyle(.secondary) }
                        .frame(maxWidth: .infinity).padding(44).background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
                } else if let profile {
                    profileContent(profile)
                } else if let error {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Profile unavailable", systemImage: "sparkles").font(.headline)
                        Text(error).supportingText()
                        Button("Try again") { Task { await load() } }.buttonStyle(.bordered).tint(tint)
                    }
                    .padding(18).background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(20)
        }
        .background(Color.space)
        .task { await load() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func profileContent(_ profile: PalateProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(profile.identity.snapshot).font(.title3.weight(.semibold))
                HStack(spacing: 8) {
                    Text("\(profile.identity.confidence)% identification confidence").font(.caption.weight(.semibold)).foregroundStyle(tint)
                    Text(profile.identity.evidence).font(.caption).foregroundStyle(.secondary)
                }
                Text(profile.summary).font(.body)
            }.padding(18).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

            ProfileSection(title: "Its story", copy: profile.story, tint: tint)
            GroupBox("Expected sensory profile") {
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(profile.sensory, id: \.name) { group in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(group.name.uppercased()).eyebrow().foregroundStyle(tint)
                            Text(group.notes.joined(separator: " · ")).font(.subheadline.weight(.medium))
                            Text(group.basis).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }.groupBoxStyle(DarkGroupBox())
            ProfileListSection(title: "Taste along with Palate", items: profile.tastingPrompts, symbol: "eye", tint: tint)
            ProfileListSection(title: "Preparation & enjoyment", items: profile.preparation, symbol: "slider.horizontal.3", tint: tint)
            if !profile.personalization.isEmpty { ProfileSection(title: "Why this may click for you", copy: profile.personalization, tint: tint) }
            ProfileSection(title: "Keep exploring", copy: profile.discovery, tint: tint)
            if !profile.caveats.isEmpty { Text(profile.caveats.joined(separator: " ")).font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do { profile = try await PalateIntelligenceService.profile(for: request) }
        catch { self.error = error.localizedDescription }
        isLoading = false
    }
}

private struct ProfileSection: View {
    let title, copy: String; let tint: Color
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title.uppercased()).eyebrow().foregroundStyle(tint); Text(copy).font(.body).fixedSize(horizontal: false, vertical: true) }.padding(18).background(Color.surface, in: RoundedRectangle(cornerRadius: 18)) }
}

private struct ProfileListSection: View {
    let title: String; let items: [String]; let symbol: String; let tint: Color
    var body: some View { GroupBox(title) { VStack(alignment: .leading, spacing: 12) { ForEach(Array(items.enumerated()), id: \.offset) { _, item in Label { Text(item).font(.subheadline) } icon: { Image(systemName: symbol).foregroundStyle(tint) } } } }.groupBoxStyle(DarkGroupBox()) }
}

private struct TastingSavedView: View { let product, message: String; let tint: Color; let destination: AnyView; var body: some View { VStack(alignment: .leading, spacing: 22) { Spacer(); Image(systemName: "checkmark").font(.title2).foregroundStyle(tint).frame(width: 48, height: 48).overlay(Circle().stroke(tint)); Text("TASTING SAVED").eyebrow().foregroundStyle(tint); Text("\(product),\nremembered.").displayTitle(); Text(message).serifMuted(); Spacer(); NavigationLink { destination } label: { HStack { Text("Back to your collection"); Spacer(); Image(systemName: "arrow.right") }.fontWeight(.bold).padding().frame(maxWidth: .infinity).background(tint, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(.black) } }.padding(24).background(Color.space).preferredColorScheme(.dark).navigationBarBackButtonHidden() } }

private struct AddWineView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var producer = ""; @State private var vintage = ""; @State private var grapes = ""; @State private var region = ""; @State private var imageData: Data?
    let save: (WineBottle) -> Void
    var body: some View { NavigationStack { Form {
        Section("Bottle scan") {
            LabelScanControl(kind: .wine, imageData: $imageData) { scan in
                if let value = scan.value("Producer") { producer = value }; if let value = scan.value("Wine name") { name = value }; if let value = scan.value("Vintage") { vintage = value }; if let value = scan.value("Grape") { grapes = value }; if let value = scan.value("Region") { region = value }
            }
            Text("Capture the front label. You’ll review every detected field before it is applied.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Bottle details") { TextField("Producer", text: $producer); TextField("Wine name", text: $name); TextField("Vintage", text: $vintage); TextField("Grape", text: $grapes); TextField("Region", text: $region) }
    }.navigationTitle("Add wine").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Add") { guard !name.isEmpty else { return }; save(WineBottle(name: name, producer: producer.isEmpty ? "Unknown producer" : producer, vintage: vintage.isEmpty ? "NV" : vintage, grapes: grapes.isEmpty ? "Unknown grape" : grapes, region: region.isEmpty ? "Origin to add" : region, country: "Unknown", latitude: 0, longitude: 0, notes: [], imageData: imageData)); dismiss() } } } }.preferredColorScheme(.dark) }
}

private struct AddScotchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var distillery = ""; @State private var age = ""; @State private var region = ""; @State private var cask = ""; @State private var abv = ""; @State private var imageData: Data?
    let save: (ScotchBottle) -> Void
    var body: some View { NavigationStack { Form {
        Section("Bottle scan") {
            LabelScanControl(kind: .scotch, imageData: $imageData) { scan in
                if let value = scan.value("Distillery") { distillery = value }; if let value = scan.value("Expression") { name = value }; if let value = scan.value("Age statement") { age = value }; if let value = scan.value("Region") { region = value }; if let value = scan.value("Cask") { cask = value }; if let value = scan.value("ABV") { abv = value }
            }
            Text("Capture the front label. You’ll review every detected field before it is applied.").font(.caption).foregroundStyle(.secondary)
        }
        Section("Bottle details") { TextField("Expression", text: $name); TextField("Distillery", text: $distillery); TextField("Age statement", text: $age); TextField("Region", text: $region); TextField("Cask", text: $cask); TextField("ABV", text: $abv) }
    }.navigationTitle("Add Scotch").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Add") { guard !name.isEmpty else { return }; save(ScotchBottle(name: name, distillery: distillery.isEmpty ? "Unknown distillery" : distillery, ageStatement: age.isEmpty ? "No age statement" : age, region: region.isEmpty ? "Scotland" : region, cask: cask.isEmpty ? "To add" : cask, abv: abv.isEmpty ? "To add" : abv, latitude: 56.82, longitude: -4.97, notes: [], imageData: imageData)); dismiss() } } } }.preferredColorScheme(.dark) }
}

private struct EditWineView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bottle: WineBottle
    @State private var draft: WineBottle
    @State private var notes: String

    init(bottle: Binding<WineBottle>) {
        _bottle = bottle
        _draft = State(initialValue: bottle.wrappedValue)
        _notes = State(initialValue: bottle.wrappedValue.notes.joined(separator: ", "))
    }

    var body: some View { NavigationStack { Form {
        Section("Bottle scan") {
            LabelScanControl(kind: .wine, imageData: $draft.imageData) { scan in
                if let value = scan.value("Producer") { draft.producer = value }
                if let value = scan.value("Wine name") { draft.name = value }
                if let value = scan.value("Vintage") { draft.vintage = value }
                if let value = scan.value("Grape") { draft.grapes = value }
                if let value = scan.value("Region") { draft.region = value }
            }
            if draft.imageData != nil { Button("Remove label photo", role: .destructive) { draft.imageData = nil } }
        }
        Section("Bottle details") {
            TextField("Producer", text: $draft.producer)
            TextField("Wine name", text: $draft.name)
            TextField("Vintage", text: $draft.vintage)
            TextField("Grape", text: $draft.grapes)
            TextField("Region", text: $draft.region)
            TextField("Country", text: $draft.country)
            TextField("Producer notes, comma separated", text: $notes)
        }
    }
    .navigationTitle("Edit wine")
    .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Done") { draft.notes = notes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }; bottle = draft; dismiss() }.disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty) }
    }
    }.preferredColorScheme(.dark) }
}

private struct EditScotchView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var bottle: ScotchBottle
    @State private var draft: ScotchBottle
    @State private var notes: String

    init(bottle: Binding<ScotchBottle>) {
        _bottle = bottle
        _draft = State(initialValue: bottle.wrappedValue)
        _notes = State(initialValue: bottle.wrappedValue.notes.joined(separator: ", "))
    }

    var body: some View { NavigationStack { Form {
        Section("Bottle scan") {
            LabelScanControl(kind: .scotch, imageData: $draft.imageData) { scan in
                if let value = scan.value("Distillery") { draft.distillery = value }
                if let value = scan.value("Expression") { draft.name = value }
                if let value = scan.value("Age statement") { draft.ageStatement = value }
                if let value = scan.value("Region") { draft.region = value }
                if let value = scan.value("Cask") { draft.cask = value }
                if let value = scan.value("ABV") { draft.abv = value }
            }
            if draft.imageData != nil { Button("Remove label photo", role: .destructive) { draft.imageData = nil } }
        }
        Section("Bottle details") {
            TextField("Expression", text: $draft.name)
            TextField("Distillery", text: $draft.distillery)
            TextField("Age statement", text: $draft.ageStatement)
            TextField("Region", text: $draft.region)
            TextField("Cask", text: $draft.cask)
            TextField("ABV", text: $draft.abv)
            TextField("Distillery notes, comma separated", text: $notes)
        }
    }
    .navigationTitle("Edit Scotch")
    .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) { Button("Done") { draft.notes = notes.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }; bottle = draft; dismiss() }.disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty) }
    }
    }.preferredColorScheme(.dark) }
}
