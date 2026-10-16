//
//  AudioPlayerManager.swift
//  MusicApp
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation
import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

/// A singleton that controls audio playback, background audio, and integration with the system Now‑Playing UI.
final class AudioPlayerManager: NSObject, ObservableObject {
    static let shared = AudioPlayerManager()
    
    // MARK: - Published State
    @Published var isPlaying: Bool = false
    @Published var currentItem: AVPlayerItem?
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var track: Track?
    
    // MARK: - Private Variables
    private var player: AVQueuePlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        configureAudioSession()
        observePlayerNotifications()
    }
    
    // MARK: - Audio Session
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback,
                                                            mode: .default,
                                                            policy: .longForm,
                                                            options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration error: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    func play(track: Track) {
        self.track = track
        guard let url = URL(string: track.streamURL) else { return }
        let playerItem = AVPlayerItem(url: url)
        self.currentItem = playerItem
        if let player = player {
            player.replaceCurrentItem(with: playerItem)
        } else {
            player = AVQueuePlayer(items: [playerItem])
            player?.automaticallyWaitsToMinimizeStalling = true
        }
        addPeriodicTimeObserver()
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func seek(to seconds: Double) {
        let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }
    
    // MARK: - Time Observation
    private func addPeriodicTimeObserver() {
        guard let player = player else { return }
        if let existing = timeObserver {
            player.removeTimeObserver(existing)
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self,
                  let durationSec = self.player?.currentItem?.duration.seconds,
                  durationSec.isFinite else { return }
            self.currentTime = time.seconds
            self.duration = durationSec
        }
    }
    
    // MARK: - Now‑Playing Info
    private func updateNowPlayingInfo() {
        var nowPlaying = [String: Any]()
        nowPlaying[MPMediaItemPropertyTitle] = track?.title ?? "Unknown"
        nowPlaying[MPMediaItemPropertyArtist] = track?.artist ?? "Unknown"
        nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlaying[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let artStr = track?.artworkURL, let artURL = URL(string: artStr) {
            URLSession.shared.dataTask(with: artURL) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    var updated = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    updated[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    DispatchQueue.main.async {
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = updated
                    }
                }
            }.resume()
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying
    }
    
    // MARK: - Player Notifications
    private func observePlayerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(itemDidFinish(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    @objc private func itemDidFinish(_ notification: Notification) {
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    // MARK: - Remote Command Center
    func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.resume()
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let ev = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: ev.positionTime)
            return .success
        }
    }
}
