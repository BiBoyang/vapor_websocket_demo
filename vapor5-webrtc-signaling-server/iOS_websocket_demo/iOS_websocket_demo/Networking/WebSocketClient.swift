//
//  WebSocketClient.swift
//  iOS_websocket_demo
//
//  Created by Codex on 2026/3/13.
//

import Foundation

final class WebSocketClient: NSObject {
    enum Event: Sendable {
        case connected
        case disconnected(reason: String)
        case text(String)
        case failure(String)
    }

    var onEvent: (@Sendable (Event) -> Void)?

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var pingTask: Task<Void, Never>?

    func connect(to url: URL) {
        disconnect()

        let session = URLSession(
            configuration: .default,
            delegate: self,
            delegateQueue: nil
        )
        let task = session.webSocketTask(with: url)

        self.session = session
        self.task = task

        task.resume()
        receiveLoop()
        startPingLoop()
    }

    func disconnect() {
        pingTask?.cancel()
        pingTask = nil

        task?.cancel(with: .goingAway, reason: nil)
        task = nil

        session?.invalidateAndCancel()
        session = nil
    }

    func send(text: String) async throws {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }

        try await task.send(.string(text))
    }

    private func receiveLoop() {
        guard let task else {
            return
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    onEvent?(.text(text))
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        onEvent?(.text(text))
                    } else {
                        onEvent?(.failure("Received non-UTF8 WebSocket frame"))
                    }
                @unknown default:
                    onEvent?(.failure("Received unsupported WebSocket frame"))
                }

                receiveLoop()
            } catch {
                onEvent?(.failure("Receive failed: \(error.localizedDescription)"))
            }
        }
    }

    private func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                guard let self, let task = self.task else {
                    return
                }

                do {
                    try await sendPing(on: task)
                } catch {
                    self.onEvent?(.failure("Ping failed: \(error.localizedDescription)"))
                    return
                }
            }
        }
    }

    private func sendPing(on task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        onEvent?(.connected)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonText: String
        if let reason, let text = String(data: reason, encoding: .utf8), !text.isEmpty {
            reasonText = text
        } else {
            reasonText = "closeCode=\(closeCode.rawValue)"
        }

        onEvent?(.disconnected(reason: reasonText))
    }
}
