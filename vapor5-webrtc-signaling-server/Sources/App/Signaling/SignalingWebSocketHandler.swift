import Foundation
import Vapor
import WebSocketKit
import SignalingShared

struct SignalingWebSocketHandler {
    let signalingService: SignalingService
    private let decoder = JSONDecoder()

    func handle(_ ws: WebSocket) {
        let context = SocketContext()

        ws.onText { _, text in
            guard let data = text.data(using: .utf8),
                  let message = try? decoder.decode(SignalingMessage.self, from: data) else {
                return
            }

            Task {
                await process(message, on: ws, context: context)
            }
        }

        ws.onClose.whenComplete { _ in
            Task {
                await signalingService.leave(context: context, reason: "disconnected from")
            }
        }
    }

    private func process(_ message: SignalingMessage, on ws: WebSocket, context: SocketContext) async {
        switch message.type {
        case .join:
            await signalingService.join(message, over: ws, context: context)

        case .offer:
            await signalingService.forwardOffer(message)

        case .answer:
            await signalingService.forwardAnswer(message)

        case .iceCandidate:
            await signalingService.forwardIceCandidate(message)

        case .leave:
            await signalingService.leave(context: context, reason: "left")

        case .roomInfo:
            break

        case .peerJoined:
            break

        case .peerLeft:
            break

        case .error:
            break
        }
    }
}
