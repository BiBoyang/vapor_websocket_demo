import Foundation
import Vapor
import WebSocketKit
import SignalingShared

struct SignalingService {
    let roomManager: RoomManager
    private let encoder = JSONEncoder()

    func join(_ message: SignalingMessage, over socket: WebSocket, context: SocketContext) async {
        guard let roomId = message.room else {
            await sendError("join requires room", to: socket, target: message.sender)
            return
        }

        let joinResult = await roomManager.joinRoom(
            roomId: roomId,
            userId: message.sender,
            socket: socket
        )

        let existingMembers: [String]
        switch joinResult {
        case .success(let members):
            existingMembers = members
            await context.setUserId(message.sender)
        case .failure(.roomFull):
            await sendError("room is full", to: socket, room: roomId, target: message.sender)
            return
        }

        print("User \(message.sender) joined room \(roomId)")

        let roomInfo = SignalingMessage(
            type: .roomInfo,
            sender: "server",
            target: message.sender,
            room: roomId,
            sdp: nil,
            candidate: nil,
            members: existingMembers
        )

        await send(roomInfo, over: socket, logPrefix: "Error sending room info")

        if !existingMembers.isEmpty {
            let updatedMembers = await roomManager.members(in: roomId)
            let joinedEvent = SignalingMessage.peerJoined(
                sender: message.sender,
                room: roomId,
                members: updatedMembers
            )
            let peerSockets = await roomManager.sockets(in: roomId, excluding: message.sender)
            await send(joinedEvent, over: peerSockets, logPrefix: "Error sending peerJoined")
        }
    }

    func leave(context: SocketContext, reason: String) async {
        guard let uid = await context.getUserId() else {
            return
        }

        if let roomId = await roomManager.leaveRoom(userId: uid) {
            print("User \(uid) \(reason) room \(roomId)")

            let updatedMembers = await roomManager.members(in: roomId)
            let leftEvent = SignalingMessage.peerLeft(
                sender: uid,
                room: roomId,
                members: updatedMembers
            )
            let peerSockets = await roomManager.sockets(in: roomId)
            await send(leftEvent, over: peerSockets, logPrefix: "Error sending peerLeft")
        }
    }

    func forwardOffer(_ message: SignalingMessage) async {
        await forwardSDP(message, as: .offer)
    }

    func forwardAnswer(_ message: SignalingMessage) async {
        await forwardSDP(message, as: .answer)
    }

    func forwardIceCandidate(_ message: SignalingMessage) async {
        guard let roomId = message.room,
              let targetId = message.target,
              let candidate = message.candidate else {
            if let socket = await socketForSender(message) {
                await sendError(
                    "iceCandidate requires room, target, and candidate",
                    to: socket,
                    room: message.room,
                    target: message.sender
                )
            }
            return
        }

        guard await roomManager.contains(roomId: roomId, userId: message.sender) else {
            if let socket = await socketForSender(message) {
                await sendError("sender is not in room", to: socket, room: roomId, target: message.sender)
            }
            return
        }

        let outbound = SignalingMessage(
            type: .iceCandidate,
            sender: message.sender,
            target: nil,
            room: roomId,
            sdp: nil,
            candidate: candidate,
            members: nil
        )

        guard let socket = await roomManager.getSocket(roomId: roomId, userId: targetId) else {
            if let senderSocket = await socketForSender(message) {
                await sendError("target peer not found", to: senderSocket, room: roomId, target: message.sender)
            }
            return
        }

        await send(outbound, over: socket, logPrefix: "Error forwarding ICE candidate")
        print("Forwarded ICE candidate from \(message.sender) to \(targetId)")
    }

    private func forwardSDP(_ message: SignalingMessage, as type: SignalingMessageType) async {
        guard let roomId = message.room,
              let targetId = message.target,
              let sdp = message.sdp else {
            if let socket = await socketForSender(message) {
                await sendError(
                    "\(type.rawValue) requires room, target, and sdp",
                    to: socket,
                    room: message.room,
                    target: message.sender
                )
            }
            return
        }

        guard await roomManager.contains(roomId: roomId, userId: message.sender) else {
            if let socket = await socketForSender(message) {
                await sendError("sender is not in room", to: socket, room: roomId, target: message.sender)
            }
            return
        }

        let outbound = SignalingMessage(
            type: type,
            sender: message.sender,
            target: nil,
            room: roomId,
            sdp: sdp,
            candidate: nil,
            members: nil
        )

        guard let socket = await roomManager.getSocket(roomId: roomId, userId: targetId) else {
            if let senderSocket = await socketForSender(message) {
                await sendError("target peer not found", to: senderSocket, room: roomId, target: message.sender)
            }
            return
        }

        await send(outbound, over: socket, logPrefix: "Error forwarding \(type.rawValue)")
        print("Forwarded \(type.rawValue) from \(message.sender) to \(targetId)")
    }

    private func socketForSender(_ message: SignalingMessage) async -> WebSocket? {
        guard let roomId = message.room else {
            return nil
        }

        return await roomManager.getSocket(roomId: roomId, userId: message.sender)
    }

    private func sendError(_ text: String, to socket: WebSocket, room: String? = nil, target: String? = nil) async {
        let message = SignalingMessage.error(
            target: target,
            room: room,
            message: text
        )
        await send(message, over: socket, logPrefix: "Error sending error response")
    }

    private func send(_ message: SignalingMessage, over socket: WebSocket, logPrefix: String) async {
        do {
            let data = try encoder.encode(message)
            try await socket.send([UInt8](data))
        } catch {
            print("\(logPrefix): \(error)")
        }
    }

    private func send(_ message: SignalingMessage, over sockets: [WebSocket], logPrefix: String) async {
        for socket in sockets {
            await send(message, over: socket, logPrefix: logPrefix)
        }
    }
}
