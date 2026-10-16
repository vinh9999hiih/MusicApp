//
//  ContentView.swift
//  MusicApp
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var player = AudioPlayerManager.shared
    @State private var searchQuery: String = ""
    @State private var searchResults: [Track] = []
    @State private var isSearching: Bool = false
    @State private var isFullScreenPlayer: Bool = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Tìm bài hát, nghệ sĩ...", text: $searchQuery)
                            .foregroundColor(.white)
                            .onSubmit {
                                performSearch()
                            }
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    if isSearching {
                        ProgressView("Đang tìm kiếm...")
                            .foregroundColor(.white)
                            .padding(.top, 40)
                        Spacer()
                    } else if searchResults.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Khám phá âm nhạc")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Nhập tên bài hát hoặc ca sĩ để bắt đầu nghe nhạc không quảng cáo")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                    } else {
                        List(searchResults) { track in
                            TrackRowView(track: track) {
                                player.play(track: track)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                        }
                        .listStyle(.plain)
                        .padding(.bottom, 70)
                    }
                }
                .navigationTitle("MusicApp")
                .background(Color.black.ignoresSafeArea())
            }
            .navigationViewStyle(.stack)
            
            // Mini Player or Full Player
            NowPlayingView(player: player, isFullScreen: $isFullScreenPlayer)
                .padding(.bottom, isFullScreenPlayer ? 0 : 8)
        }
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        NetworkManager.shared.search(query: searchQuery) { tracks in
            DispatchQueue.main.async {
                self.searchResults = tracks
                self.isSearching = false
            }
        }
    }
}

struct TrackRowView: View {
    let track: Track
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: track.artworkURL ?? "")) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(track.artist)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "play.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 4)
        }
    }
}
