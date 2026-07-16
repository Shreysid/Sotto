import FluidAudio
import Foundation
import os

extension SpeechController {
    func isKokoroInstalled() -> Bool {
        kokoroInstallationProgress() >= 1
    }

    func kokoroInstallationProgress() -> Double {
        guard let cacheRoot = try? TtsCacheDirectory.ensure() else { return 0 }

        let modelsDirectory = cacheRoot.appendingPathComponent(KokoroAneResourceDownloader.modelsSubdirectory)
        let kokoroDirectory = modelsDirectory.appendingPathComponent(Repo.kokoroAne.folderName)
        let g2pDirectory = modelsDirectory.appendingPathComponent(Repo.kokoro.folderName)

        let requiredURLs = ModelNames.KokoroAne.requiredModels.map {
            kokoroDirectory.appendingPathComponent($0)
        } + ModelNames.G2P.requiredModels.map {
            g2pDirectory.appendingPathComponent($0)
        }

        guard !requiredURLs.isEmpty else { return 0 }
        let installedCount = requiredURLs.filter { FileManager.default.fileExists(atPath: $0.path) }.count
        return Double(installedCount) / Double(requiredURLs.count)
    }

    func downloadKokoro(onProgress: @escaping @Sendable (Double) -> Void) async throws {
        let cacheRoot = try TtsCacheDirectory.ensure()
        let modelsDirectory = cacheRoot.appendingPathComponent(KokoroAneResourceDownloader.modelsSubdirectory)
        onProgress(kokoroInstallationProgress())

        try await KokoroAneResourceDownloader.ensureModels(directory: modelsDirectory) { progress in
            onProgress(progress.fractionCompleted * 0.85)
        }
        try await KokoroAneResourceDownloader.ensureG2PAssets(directory: modelsDirectory) { progress in
            onProgress(0.85 + progress.fractionCompleted * 0.15)
        }

        onProgress(1)
        try await prepare()
    }

    func deleteKokoroModels() throws {
        stop()
        isPrepared = false
        kokoroUsingFallback = false
        kokoro = KokoroAneManager(defaultVoice: "af_heart")

        let cacheRoot = try TtsCacheDirectory.ensure()
        let modelsDirectory = cacheRoot.appendingPathComponent(KokoroAneResourceDownloader.modelsSubdirectory)
        let paths = [
            modelsDirectory.appendingPathComponent(Repo.kokoroAne.folderName),
            modelsDirectory.appendingPathComponent(Repo.kokoro.folderName),
        ]

        for path in paths where FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }

    func prepare() async throws {
        guard !isPrepared else { return }
        do {
            try await kokoro.initialize()
            _ = try await kokoro.synthesizeDetailed(text: "Ready.")
        } catch {
            guard !kokoroUsingFallback else { throw error }
            kokoroUsingFallback = true
            kokoro = KokoroAneManager(
                defaultVoice: "af_heart",
                computeUnits: .cpuAndGpu
            )
            try await kokoro.initialize()
            _ = try await kokoro.synthesizeDetailed(text: "Ready.")
        }
        isPrepared = true
        let accelerator = kokoroUsingFallback ? "CPU/GPU fallback" : "ANE"
        logger.info("Kokoro pre-warmed using \(accelerator, privacy: .public)")
    }
}
