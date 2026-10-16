//
//  NetworkManager.swift
//  MusicApp
//
//  Created by Senior iOS Developer on 2026-10-16.
//

import Foundation
import Combine

/// Network layer connecting to Piped / Invidious API for audio search and streaming.
final class NetworkManager {
    static let shared = NetworkManager()
    private let session = URLSession(configuration: .default)
    private var cancellables = Set<AnyCancellable>()
    
    // Multiple instances for high reliability
    private let apiInstances = [
        "https://pipedapi.kavin.rocks",
        "https://api.piped.privacy.com.de",
        "https://piped-api.lunar.icu"
    ]
    
    func search(query: String, maxResults: Int = 15, completion: @escaping ([Track]) -> Void) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion([])
            return
        }
        
        let baseURL = apiInstances.first!
        guard let url = URL(string: "\(baseURL)/search?q=\(encoded)&filter=music_songs") else {
            completion([])
            return
        }
        
        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                completion([])
                return
            }
            
            do {
                let response = try JSONDecoder().decode(PipedSearchResponse.self, from: data)
                let tracks: [Track] = response.items.compactMap { item in
                    guard let urlStr = item.url, let title = item.title else { return nil }
                    let videoID = urlStr.replacingOccurrences(of: "/watch?v=", with: "")
                    let streamURL = "\(baseURL)/streams/\(videoID)"
                    return Track(
                        title: title,
                        artist: item.uploaderName ?? "Unknown Artist",
                        album: nil,
                        artworkURL: item.thumbnail,
                        streamURL: streamURL,
                        videoID: videoID,
                        duration: Double(item.duration ?? 0)
                    )
                }
                completion(tracks)
            } catch {
                completion([])
            }
        }.resume()
    }
}

// MARK: - Decodable Models
struct PipedSearchResponse: Decodable {
    let items: [PipedSearchItem]
    
    enum CodingKeys: String, CodingKey {
        case items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.items = (try? container.decode([PipedSearchItem].self, forKey: .items)) ?? []
    }
}

struct PipedSearchItem: Decodable {
    let url: String?
    let title: String?
    let thumbnail: String?
    let uploaderName: String?
    let duration: Int?
}
