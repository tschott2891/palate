import SwiftUI
import UIKit
@preconcurrency import Vision
import PhotosUI
import ImageIO
@preconcurrency import AVFoundation

enum LabelKind {
    case coffee, wine, scotch
}

struct LabelScanResult: Identifiable {
    let id = UUID()
    let imageData: Data
    let fields: [(label: String, value: String)]
    let recognizedLines: [String]

    func value(_ label: String) -> String? {
        fields.first(where: { $0.label == label })?.value
    }

    func date(_ label: String) -> Date? {
        guard let text = value(label) else { return nil }
        let formats = ["MMM d, yyyy", "MMMM d, yyyy", "MMM d yyyy", "MMMM d yyyy", "M/d/yyyy", "MM/dd/yyyy", "M-d-yyyy", "MM-dd-yyyy", "M/d/yy", "MM/dd/yy"]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

struct LabelScanControl: View {
    let kind: LabelKind
    @Binding var imageData: Data?
    let apply: (LabelScanResult) -> Void

    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var result: LabelScanResult?
    @State private var isScanning = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Menu {
                Button { showCamera = true } label: { Label("Take photo", systemImage: "camera") }
                PhotosPicker(selection: $selectedPhoto, matching: .images) { Label("Choose from library", systemImage: "photo.on.rectangle") }
            } label: {
                HStack {
                    Label(isScanning ? "Reading label…" : "Scan label", systemImage: "camera.viewfinder")
                    Spacer()
                    if isScanning { ProgressView() } else { Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .disabled(isScanning)

            if let imageData {
                HStack(spacing: 12) {
                    ScannerThumbnail(data: imageData)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Label attached").font(.subheadline.weight(.semibold))
                        Text("Scan again to replace it").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                guard let image else { return }
                process(image)
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                process(image)
            }
        }
        .sheet(item: $result) { scan in
            LabelScanReview(result: scan) {
                imageData = scan.imageData
                apply(scan)
                result = nil
            } retry: {
                result = nil
                showCamera = true
            }
        }
        .alert("Couldn’t scan label", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Please try again in brighter, even light.") }
    }

    private func process(_ image: UIImage) {
        isScanning = true
        Task {
            do {
                let scan = try await LabelRecognizer.scan(image: image, kind: kind)
                await MainActor.run { result = scan; isScanning = false }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isScanning = false }
            }
        }
    }
}

private struct LabelScanReview: View {
    @Environment(\.dismiss) private var dismiss
    let result: LabelScanResult
    let apply: () -> Void
    let retry: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        ScannerThumbnail(data: result.imageData).frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Review detected details").font(.headline)
                            Text("Nothing is added until you apply these suggestions.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Suggested fields") {
                    if result.fields.isEmpty {
                        Text("No structured details were detected. Retake the photo straight-on in brighter light.").foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(result.fields.enumerated()), id: \.offset) { _, field in
                            LabeledContent(field.label, value: field.value)
                        }
                    }
                }
                Section("Recognized text") {
                    Text(result.recognizedLines.joined(separator: "\n"))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Label scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Apply") { apply() }.disabled(result.fields.isEmpty) }
                ToolbarItem(placement: .bottomBar) { Button("Retake photo") { retry() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ScannerThumbnail: View {
    let data: Data
    var body: some View {
        Group {
            if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").foregroundStyle(.secondary) }
        }
        .frame(width: 52, height: 52)
        .background(.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> LabelCameraViewController { LabelCameraViewController(completion: completion) }
    func updateUIViewController(_ uiViewController: LabelCameraViewController, context: Context) {}
}

private final class LabelCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.tschott.Palate.camera")
    private let completion: (UIImage?) -> Void
    private let previewView = CameraPreviewView()
    private let shutterButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var didConfigure = false

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor), previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor), previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        installControls()
        updateStatus("Starting camera…")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        requestCameraAccess()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configureSessionIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async { granted ? self?.configureSessionIfNeeded() : self?.showPermissionMessage() }
            }
        case .denied, .restricted: showPermissionMessage()
        @unknown default: showPermissionMessage()
        }
    }

    private func configureSessionIfNeeded() {
        guard !didConfigure else { startSession(); return }
        updateStatus("Connecting to camera…")
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInDualWideCamera], mediaType: .video, position: .back)
            guard let camera = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
                DispatchQueue.main.async { self.showUnavailableMessage(reason: "No camera device was found.") }; return
            }
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.showUnavailableMessage(reason: "The camera input could not be connected.") }
                    return
                }
                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.session.commitConfiguration()
                self.didConfigure = true
                DispatchQueue.main.async { self.previewView.session = self.session }
                self.session.startRunning()
                DispatchQueue.main.async {
                    if self.session.isRunning { self.updateStatus(nil); self.shutterButton.isEnabled = true }
                    else { self.showUnavailableMessage(reason: "The capture session did not start.") }
                }
            } catch {
                DispatchQueue.main.async { self.showUnavailableMessage(reason: error.localizedDescription) }
            }
        }
    }

    private func startSession() {
        updateStatus("Starting camera…")
        shutterButton.isEnabled = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async {
                if self.session.isRunning { self.updateStatus(nil); self.shutterButton.isEnabled = true }
                else { self.showUnavailableMessage(reason: "The capture session did not restart.") }
            }
        }
    }

    private func installControls() {
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.accessibilityLabel = "Take photo"
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 36
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        shutterButton.layer.borderWidth = 5
        shutterButton.isEnabled = false
        shutterButton.addTarget(self, action: #selector(takePhoto), for: .touchUpInside)

        let cancel = UIButton(type: .system)
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.setTitle("Cancel", for: .normal)
        cancel.setTitleColor(.white, for: .normal)
        cancel.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        cancel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        cancel.layer.cornerRadius = 18
        cancel.addTarget(self, action: #selector(cancelCapture), for: .touchUpInside)

        let instruction = UILabel()
        instruction.translatesAutoresizingMaskIntoConstraints = false
        instruction.text = "Fill the frame with the front label"
        instruction.textColor = .white
        instruction.font = .preferredFont(forTextStyle: .subheadline)
        instruction.textAlignment = .center
        instruction.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        instruction.layer.cornerRadius = 16
        instruction.clipsToBounds = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .white
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        statusLabel.layer.cornerRadius = 16
        statusLabel.clipsToBounds = true

        view.addSubview(shutterButton); view.addSubview(cancel); view.addSubview(instruction); view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            shutterButton.widthAnchor.constraint(equalToConstant: 72), shutterButton.heightAnchor.constraint(equalToConstant: 72),
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor), shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            cancel.widthAnchor.constraint(equalToConstant: 86), cancel.heightAnchor.constraint(equalToConstant: 38),
            cancel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 18), cancel.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            instruction.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18), instruction.centerXAnchor.constraint(equalTo: view.centerXAnchor), instruction.heightAnchor.constraint(equalToConstant: 34), instruction.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.86),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor), statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor), statusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.82), statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
    }

    @objc private func takePhoto() {
        guard session.isRunning else { showUnavailableMessage(reason: "The camera session is not running."); return }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = output.supportedFlashModes.contains(.auto) ? .auto : .off
        output.capturePhoto(with: settings, delegate: self)
    }

    @objc private func cancelCapture() { completion(nil) }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { showUnavailableMessage(reason: error?.localizedDescription ?? "The captured photo could not be read."); return }
        completion(image)
    }

    private func showPermissionMessage() {
        showMessage(title: "Camera access is off", message: "Allow camera access in Settings to scan labels.", includeSettings: true)
    }

    private func showUnavailableMessage(reason: String) {
        updateStatus("Camera unavailable\n\(reason)")
        showMessage(title: "Camera unavailable", message: "\(reason) You can still choose a label from your photo library.", includeSettings: false)
    }

    private func updateStatus(_ message: String?) {
        statusLabel.text = message.map { "  \($0)  " }
        statusLabel.isHidden = message == nil
    }

    private func showMessage(title: String, message: String, includeSettings: Bool) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if includeSettings { alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }) }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.completion(nil) })
        present(alert, animated: true)
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue; previewLayer.videoGravity = .resizeAspectFill }
    }
}

enum LabelRecognizer {
    static func scan(image: UIImage, kind: LabelKind) async throws -> LabelScanResult {
        guard let cgImage = image.cgImage else { throw ScanError.invalidImage }
        let lines = try await recognize(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation))
        guard !lines.isEmpty else { throw ScanError.noText }
        guard let data = image.jpegData(compressionQuality: 0.78) else { throw ScanError.invalidImage }
        return LabelScanResult(imageData: data, fields: suggestions(from: lines, kind: kind), recognizedLines: lines)
    }

    private static func recognize(cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "fr-FR", "it-IT", "es-ES"]
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cgImage, orientation: orientation).perform([request]) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func suggestions(from lines: [String], kind: LabelKind) -> [(String, String)] {
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count > 1 }
        func first(containing terms: [String]) -> String? { cleaned.first { line in terms.contains { line.localizedCaseInsensitiveContains($0) } } }
        func firstMatch(_ pattern: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            for line in cleaned {
                let range = NSRange(line.startIndex..., in: line)
                if let match = regex.firstMatch(in: line, range: range), let swiftRange = Range(match.range, in: line) { return String(line[swiftRange]) }
            }
            return nil
        }
        func primary(_ index: Int) -> String? { cleaned.indices.contains(index) ? cleaned[index] : nil }
        func add(_ label: String, _ value: String?, to fields: inout [(String, String)]) { if let value, !value.isEmpty, !fields.contains(where: { $0.0 == label }) { fields.append((label, value)) } }

        var fields: [(String, String)] = []
        switch kind {
        case .coffee:
            add("Roaster", primary(0), to: &fields)
            add("Coffee name", primary(1), to: &fields)
            add("Origin", first(containing: ["Ethiopia", "Colombia", "Kenya", "Guatemala", "Costa Rica", "Brazil", "Rwanda", "Burundi", "Panama", "Honduras", "Peru", "Indonesia", "Mexico", "Ecuador", "Yemen"]), to: &fields)
            add("Process", first(containing: ["washed", "natural", "anaerobic", "honey", "carbonic", "wet hulled"]), to: &fields)
            add("Roast date", firstMatch("(?:Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\\s+\\d{1,2}(?:,|\\s)+20\\d{2}|\\d{1,2}[/-]\\d{1,2}[/-](?:20)?\\d{2}"), to: &fields)
        case .wine:
            add("Producer", primary(0), to: &fields)
            add("Wine name", primary(1), to: &fields)
            add("Vintage", firstMatch("\\b(?:19|20)\\d{2}\\b"), to: &fields)
            add("Grape", first(containing: ["Pinot Noir", "Cabernet Sauvignon", "Chardonnay", "Sauvignon Blanc", "Nebbiolo", "Sangiovese", "Riesling", "Syrah", "Merlot", "Tempranillo", "Grenache", "Malbec"]), to: &fields)
            add("Region", first(containing: ["Bordeaux", "Burgundy", "Champagne", "Napa", "Sonoma", "Willamette", "Piedmont", "Tuscany", "Rioja", "Mosel", "Barossa", "Mendoza", "Rhône", "Loire"]), to: &fields)
        case .scotch:
            add("Distillery", primary(0), to: &fields)
            add("Expression", primary(1), to: &fields)
            add("Age statement", firstMatch("\\b\\d{1,2}\\s*(?:year|years|yr|yo)(?:\\s*old)?\\b"), to: &fields)
            add("Region", first(containing: ["Speyside", "Islay", "Highland", "Lowland", "Campbeltown", "Island"]), to: &fields)
            add("Cask", first(containing: ["sherry", "bourbon", "port cask", "rum cask", "wine cask", "oak cask"]), to: &fields)
            add("ABV", firstMatch("\\b\\d{2}(?:\\.\\d)?%\\s*(?:ABV|vol)?\\b"), to: &fields)
        }
        return fields
    }

    enum ScanError: LocalizedError {
        case invalidImage, noText
        var errorDescription: String? {
            switch self {
            case .invalidImage: "The image couldn’t be read."
            case .noText: "No readable text was found on the label."
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up; case .down: self = .down; case .left: self = .left; case .right: self = .right
        case .upMirrored: self = .upMirrored; case .downMirrored: self = .downMirrored; case .leftMirrored: self = .leftMirrored; case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
