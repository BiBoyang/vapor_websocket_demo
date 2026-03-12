//
//  SignalingClient.swift
//  iOS_websocket_demo
//
//  Created by Codex on 2026/3/13.
//

import Foundation
import SignalingShared

@MainActor
final class SignalingClient {
    enum Event: Sendable {
        case connected
        case disconnected(String)
        case message(SignalingMessage)
        case failure(String)
    }

    var onEvent: (@Sendable (Event) -> Void)?

    private let socketClient = WebSocketClient()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        socketClient.onEvent = { [weak self] event in
            Task { @MainActor [weak self, event] in
                self?.handleSocketEvent(event)
            }
        }
    }

    func connect(urlString: String) throws {
        guard let url = URL(string: urlString) else {
            throw SignalingClientError.invalidURL
        }

        socketClient.connect(to: url)
    }

    func disconnect() {
        socketClient.disconnect()
    }

    func send(_ message: SignalingMessage) async throws {
        let data = try encoder.encode(message)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SignalingClientError.encodingFailed
        }

        try await socketClient.send(text: text)
    }

    private func handleSocketEvent(_ event: WebSocketClient.Event) {
        switch event {
        case .connected:
            onEvent?(.connected)

        case .disconnected(let reason):
            onEvent?(.disconnected(reason))

        case .text(let text):
            decode(text: text)

        case .failure(let message):
            onEvent?(.failure(message))
        }
    }

    private func decode(text: String) {
        guard let data = text.data(using: .utf8) else {
            onEvent?(.failure("Failed to decode UTF-8 WebSocket payload"))
            return
        }

        do {
            let message = try decoder.decode(SignalingMessage.self, from: data)
            onEvent?(.message(message))
        } catch {
            onEvent?(.failure("Failed to decode signaling message: \(error.localizedDescription)"))
        }
    }
}

enum SignalingClientError: LocalizedError {
    case invalidURL
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The WebSocket URL is invalid."
        case .encodingFailed:
            return "The signaling message could not be encoded."
        }
    }
}
