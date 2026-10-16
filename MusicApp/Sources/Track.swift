//
//  Track.swift
//  MusicApp
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation

public struct Track: Identifiable, Hashable, Codable {
    public var id: String { videoID ?? streamURL }
    public let title: String
    public let artist: String
    public let album: String?
    public let artworkURL: String?
    public let streamURL: String
    public let videoID: String?
    public let duration: Double
    public let isrc: String?

    public init(
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: String? = nil,
        streamURL: String,
        videoID: String? = nil,
        duration: Double = 0,
        isrc: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.streamURL = streamURL
        self.videoID = videoID
        self.duration = duration
        self.isrc = isrc
    }
}
