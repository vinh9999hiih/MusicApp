//  LyricsManager.swift
//  MusicApp
//
//  Created by Senior iOS Developer on 2026-10-16.

import Foundation
import Combine

/// Handles fetching and parsing of LRC‑formatted lyrics from LRCLIB.
final class LyricsManager: ObservableObject {
    @Published var lyrics: [LyricLine] = []
    @Published var currentLineIndex: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?
    
    // MARK: - Public API
    /// Fetch lyrics for the given track (uses videoID if available).
    func fetchLyrics(for track: Track) {
        guard let videoID = track.videoID else {
            self.lyrics = []
            return
        }
        let query = "https://lrclib.net/api/get?track_name=\(track.title.urlEncoded)&artist_name=\(track.artist.urlEncoded)&album_name=\(track.album?.urlEncoded ?? "")&duration=\(Int(track.duration))&isrc=\(track.isrc ?? "")&video_id=\(videoID)"
        guard let url = URL(string: query) else {
            self.lyrics = []
            return
        }
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: LRCLibResponse.self, decoder: JSONDecoder())
            .replaceError(with: LRCLibResponse(plainLyrics: "", syncedLyrics: nil, sourceURL: nil))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] resp in
                self?.parseLRC(resp.syncedLyrics ?? resp.plainLyrics)
            }
            .store(in: &cancellables)
    }
    
    /// Start syncing lyric highlight with playback.
    func startSync(with player: AudioPlayerManager) {
        timer?.cancel()
        timer = Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let current = player.currentTime
                self.updateCurrentLine(for: current)
            }
    }
    
    func stopSync() {
        timer?.cancel()
        timer = nil
    }
    
    // MARK: - Private Helpers
    private func parseLRC(_ raw: String) {
        var result: [LyricLine] = []
        let pattern = #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        raw.enumerateLines { line, _ in
            guard let match = regex?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
                  match.numberOfRanges == 5 else { return }
            let minR = Range(match.range(at: 1), in: line)!
            let secR = Range(match.range(at: 2), in: line)!
            let msR = Range(match.range(at: 3), in: line)!
            let txtR = Range(match.range(at: 4), in: line)!
            let minutes = Double(line[minR]) ?? 0
            let seconds = Double(line[secR]) ?? 0
            let msString = String(line[msR])
            let ms = Double(msString) ?? 0
            let total = minutes * 60 + seconds + ms / (msString.count == 2 ? 100 : 1000)
            let text = String(line[txtR]).trimmingCharacters(in: .whitespaces)
            result.append(LyricLine(timestamp: total, text: text))
        }
        self.lyrics = result.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func updateCurrentLine(for time: Double) {
        guard !lyrics.isEmpty else { return }
        var idx = 0
        for (i, line) in lyrics.enumerated() {
            if line.timestamp <= time {
                idx = i
            } else { break }
        }
        if idx != currentLineIndex { currentLineIndex = idx }
    }
}

// Supporting structs
struct LyricLine: Identifiable {
    let id = UUID()
    let timestamp: Double
    let text: String
}

struct LRCLibResponse: Decodable {
    let plainLyrics: String
    let syncedLyrics: String?
    let sourceURL: String?
}

extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
