//
//  NowPlayingView.swift
//  MusicApp
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI
import AVKit
import CoreImage

struct NowPlayingView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @StateObject var lyricsMgr = LyricsManager()
    @Namespace private var anim
    @Binding var isFullScreen: Bool
    
    var body: some View {
        ZStack {
            if isFullScreen {
                GradientBackgroundView(artworkURL: player.track?.artworkURL)
                    .ignoresSafeArea()
                    .blur(radius: 20)
                    .transition(.opacity)
                
                FullPlayerView(lyricsMgr: lyricsMgr, isFullScreen: $isFullScreen)
                    .matchedGeometryEffect(id: "player_container", in: anim)
                    .transition(.move(edge: .bottom))
            } else {
                MiniPlayerView(isFullScreen: $isFullScreen)
                    .matchedGeometryEffect(id: "player_container", in: anim)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isFullScreen)
        .onAppear {
            player.setupRemoteCommands()
            if let t = player.track {
                lyricsMgr.fetchLyrics(for: t)
                lyricsMgr.startSync(with: player)
            }
        }
        .onChange(of: player.track) { newTrack in
            if let t = newTrack {
                lyricsMgr.fetchLyrics(for: t)
                lyricsMgr.startSync(with: player)
            }
        }
        .onDisappear {
            lyricsMgr.stopSync()
        }
    }
}

// MARK: - Mini Player
struct MiniPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @Binding var isFullScreen: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: player.track?.artworkURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(player.track?.title ?? "Chưa phát bài nào")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.white)
                
                Text(player.track?.artist ?? "MusicApp")
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: { player.togglePlayPause() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                isFullScreen = true
            }
        }
    }
}

// MARK: - Full‑Screen Player
struct FullPlayerView: View {
    @ObservedObject private var player = AudioPlayerManager.shared
    @ObservedObject var lyricsMgr: LyricsManager
    @Binding var isFullScreen: Bool
    @State private var showLyrics: Bool = false
    
    var body: some View {
        VStack(spacing: 18) {
            // Top Grabber & Dismiss
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        isFullScreen = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(10)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                
                Spacer()
                
                Button(action: { withAnimation { showLyrics.toggle() } }) {
                    Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(showLyrics ? .green : .white.opacity(0.8))
                        .padding(10)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            if showLyrics {
                LyricsView(mgr: lyricsMgr)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 24)
            } else {
                Spacer()
                
                // Artwork
                AsyncImage(url: URL(string: player.track?.artworkURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 280, height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.5), radius: 25, x: 0, y: 15)
                
                Spacer()
            }
            
            // Track Info
            VStack(spacing: 4) {
                Text(player.track?.title ?? "Unknown")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(player.track?.artist ?? "Unknown")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 32)
            
            // Progress Bar
            VStack(spacing: 6) {
                Slider(value: Binding(
                    get: { player.currentTime },
                    set: { player.seek(to: $0) }
                ), in: 0...max(player.duration, 1))
                .accentColor(.white)
                
                HStack {
                    Text(formatTime(player.currentTime))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text(formatTime(player.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 32)
            
            // Playback Controls
            HStack(spacing: 48) {
                Button(action: { player.seek(to: max(0, player.currentTime - 10)) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                
                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.white)
                }
                
                Button(action: { player.seek(to: min(player.duration, player.currentTime + 10)) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 36)
        }
        .background(.ultraThinMaterial)
    }
    
    private func formatTime(_ time: Double) -> String {
        let total = Int(time)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Lyrics View
struct LyricsView: View {
    @ObservedObject var mgr: LyricsManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if mgr.lyrics.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Không có lời bài hát đồng bộ")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Array(mgr.lyrics.enumerated()), id: \.element.id) { idx, line in
                            let isCurrent = idx == mgr.currentLineIndex
                            Text(line.text)
                                .font(.system(size: isCurrent ? 24 : 18, weight: isCurrent ? .bold : .medium))
                                .foregroundColor(isCurrent ? .white : .white.opacity(0.35))
                                .scaleEffect(isCurrent ? 1.05 : 1.0, anchor: .leading)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: mgr.currentLineIndex)
                                .id(line.id)
                        }
                    }
                    .padding(.vertical, 24)
                }
            }
            .onChange(of: mgr.currentLineIndex) { idx in
                if idx < mgr.lyrics.count {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(mgr.lyrics[idx].id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Gradient Background based on artwork
struct GradientBackgroundView: View {
    let artworkURL: String?
    @State private var dominantColor: Color = Color(red: 0.12, green: 0.12, blue: 0.22)
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [dominantColor.opacity(0.85), Color.black]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .onAppear {
            extractColor()
        }
        .onChange(of: artworkURL) { _ in
            extractColor()
        }
    }
    
    private func extractColor() {
        guard let urlStr = artworkURL, let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            if let avg = uiImage.averageColor {
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.dominantColor = Color(avg)
                    }
                }
            }
        }.resume()
    }
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }
        
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        return UIColor(
            red: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1.0
        )
    }
}
