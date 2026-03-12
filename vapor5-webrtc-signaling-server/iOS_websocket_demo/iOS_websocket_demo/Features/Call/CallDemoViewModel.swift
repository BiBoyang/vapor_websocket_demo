//
//  CallDemoViewModel.swift
//  iOS_websocket_demo
//
//  Created by Codex on 2026/3/13.
//

import Foundation
import Combine
import SignalingShared

@MainActor
final class CallDemoViewModel: ObservableObject {
    enum ConnectionState: String {
        case disconnected
        case connecting
        case connected
    }

    enum PeerState: String {
        case unknown
        case waiting
        case present
        case left
    }

    @Published var serverURL = "ws://127.0.0.1:8080/signaling"
    @Published var userID = "user-a"
    @Published var roomID = "room-001"
    @Published var targetUserID = "user-b"
    @Published var sdpText = """
v=0
o=- 0 0 IN IP4 127.0.0.1
s=iOS WebSocket Demo
t=0 0
a=group:BUNDLE 0
"""
    @Published var candidateText = "candidate:demo 1 udp 2122260223 192.168.1.2 54321 typ host"
    @Published var connectionState: ConnectionState = .disconnected
    @Published var members: [String] = []
    @Published var logs: [String] = []
    @Published var currentRoomStatus = "Not joined"
    @Published var peerState: PeerState = .unknown
    @Published var lastIncomingMessage = "None"
    @Published var lastServerError = "None"
    @Published var peerID = "Unknown"

    private let signalingClient = SignalingClient()
    private var hasJoinedRoom = false

    init() {
        signalingClient.onEvent = { [weak self] event in
            Task { @MainActor [weak self, event] in
                self?.handle(event: event)
            }
        }
    }

    func connect() {
        guard connectionState == .disconnected else {
            appendLog("Connect skipped because socket is already active")
            return
        }

        connectionState = .connecting

        do {
            try signalingClient.connect(urlString: serverURL)
            appendLog("Connecting to \(serverURL)")
        } catch {
            connectionState = .disconnected
            appendLog("Connect failed: \(error.localizedDescription)")
        }
    }

    func disconnect() {
        if hasJoinedRoom {
            Task {
                await leaveRoom()
            }
        }

        signalingClient.disconnect()
        hasJoinedRoom = false
        members = []
        connectionState = .disconnected
        currentRoomStatus = "Not joined"
        peerState = .unknown
        lastIncomingMessage = "None"
        appendLog("Socket disconnected")
    }

    func joinRoom() async {
        guard connectionState == .connected else {
            appendLog("Join blocked: socket is not connected")
            return
        }

        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        let userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !roomID.isEmpty, !userID.isEmpty else {
            appendLog("Join blocked: user ID and room ID are required")
            return
        }

        do {
            try await signalingClient.send(.join(sender: userID, room: roomID))
            hasJoinedRoom = true
            currentRoomStatus = "Joining \(roomID)"
            peerState = .waiting
            appendLog("Sent join for room \(roomID) as \(userID)")
        } catch {
            appendLog("Join failed: \(error.localizedDescription)")
        }
    }

    func leaveRoom() async {
        let userID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        let roomID = roomID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !userID.isEmpty else {
            appendLog("Leave blocked: user ID is empty")
            return
        }

        do {
            try await signalingClient.send(.leave(sender: userID, room: roomID.isEmpty ? nil : roomID))
            hasJoinedRoom = false
            members = []
            currentRoomStatus = "Left room"
            peerState = .left
            appendLog("Sent leave")
        } catch {
            appendLog("Leave failed: \(error.localizedDescription)")
        }
    }

    func sendOffer() async {
        await sendSDPMessage(type: .offer)
    }

    func sendAnswer() async {
        await sendSDPMessage(type: .answer)
    }

    func sendCandidate() async {
        let sender = trimmed(userID)
        let room = trimmed(roomID)
        let target = trimmed(targetUserID)
        let candidateText = trimmed(candidateText)

        guard canSendToPeer(sender: sender, room: room, target: target) else {
            return
        }

        guard !candidateText.isEmpty else {
            appendLog("ICE send blocked: candidate text is empty")
            return
        }

        let candidate = ICECandidate(
            sdpMid: "0",
            sdpMLineIndex: 0,
            candidate: candidateText
        )

        do {
            try await signalingClient.send(
                .iceCandidate(
                    sender: sender,
                    target: target,
                    room: room,
                    candidate: candidate
                )
            )
            appendLog("Sent ICE candidate to \(target)")
        } catch {
            appendLog("ICE send failed: \(error.localizedDescription)")
        }
    }

    private func sendSDPMessage(type: SignalingMessageType) async {
        let sender = trimmed(userID)
        let room = trimmed(roomID)
        let target = trimmed(targetUserID)
        let sdpText = trimmed(sdpText)

        guard canSendToPeer(sender: sender, room: room, target: target) else {
            return
        }

        guard !sdpText.isEmpty else {
            appendLog("\(type.rawValue) blocked: SDP is empty")
            return
        }

        let message: SignalingMessage
        switch type {
        case .offer:
            message = .offer(sender: sender, target: target, room: room, sdp: sdpText)
        case .answer:
            message = .answer(sender: sender, target: target, room: room, sdp: sdpText)
        default:
            assertionFailure("Unexpected SDP message type")
            return
        }

        do {
            try await signalingClient.send(message)
            appendLog("Sent \(type.rawValue) to \(target)")
        } catch {
            appendLog("\(type.rawValue) failed: \(error.localizedDescription)")
        }
    }

    private func canSendToPeer(sender: String, room: String, target: String) -> Bool {
        guard connectionState == .connected else {
            appendLog("Send blocked: socket is not connected")
            return false
        }

        guard hasJoinedRoom else {
            appendLog("Send blocked: join the room before sending signaling messages")
            return false
        }

        guard !sender.isEmpty, !room.isEmpty, !target.isEmpty else {
            appendLog("Send blocked: sender, room, and target are required")
            return false
        }

        return true
    }

    private func handle(event: SignalingClient.Event) {
        switch event {
        case .connected:
            connectionState = .connected
            appendLog("WebSocket connected")

        case .disconnected(let reason):
            connectionState = .disconnected
            hasJoinedRoom = false
            members = []
            currentRoomStatus = "Disconnected"
            peerState = .unknown
            appendLog("WebSocket closed: \(reason)")

        case .message(let message):
            handle(message: message)

        case .failure(let message):
            appendLog("Socket error: \(message)")
        }
    }

    private func handle(message: SignalingMessage) {
        lastIncomingMessage = message.type.rawValue

        switch message.type {
        case .roomInfo:
            members = message.members ?? []
            currentRoomStatus = hasJoinedRoom ? "Joined \(trimmed(roomID))" : "Room info received"
            updatePeerState(from: members)
            appendLog("Room members: \(members.joined(separator: ", "))")

        case .offer:
            appendLog("Received offer from \(message.sender)")
            if let sdp = message.sdp {
                sdpText = sdp
            }
            targetUserID = message.sender
            peerID = message.sender
            peerState = .present

        case .answer:
            appendLog("Received answer from \(message.sender)")
            if let sdp = message.sdp {
                sdpText = sdp
            }
            targetUserID = message.sender
            peerID = message.sender
            peerState = .present

        case .iceCandidate:
            appendLog("Received ICE candidate from \(message.sender)")
            if let candidate = message.candidate?.candidate {
                candidateText = candidate
            }
            targetUserID = message.sender
            peerID = message.sender
            peerState = .present

        case .join:
            appendLog("Received join message from \(message.sender)")

        case .leave:
            appendLog("Received leave message from \(message.sender)")
            peerState = .left

        case .peerJoined:
            members = message.members ?? members
            peerID = message.sender
            peerState = .present
            currentRoomStatus = "Peer joined \(trimmed(roomID))"
            appendLog("Peer joined: \(message.sender)")

        case .peerLeft:
            members = message.members ?? []
            peerID = message.sender
            peerState = .left
            currentRoomStatus = "Peer left \(trimmed(roomID))"
            appendLog("Peer left: \(message.sender)")

        case .error:
            lastServerError = message.sdp ?? "unknown error"
            appendLog("Server error: \(lastServerError)")
        }
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        logs.insert("[\(formatter.string(from: Date()))] \(message)", at: 0)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updatePeerState(from members: [String]) {
        let currentUser = trimmed(userID)
        let otherMembers = members.filter { $0 != currentUser }

        if let peer = otherMembers.first {
            peerID = peer
            peerState = .present
        } else if hasJoinedRoom {
            peerID = "Waiting"
            peerState = .waiting
        } else {
            peerID = "Unknown"
            peerState = .unknown
        }
    }
}
