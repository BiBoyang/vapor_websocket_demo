import Foundation

public enum SignalingMessageType: String, Codable, CaseIterable, Sendable {
    case join
    case leave
    case peerJoined
    case peerLeft
    case offer
    case answer
    case iceCandidate
    case roomInfo
    case error
}

public struct ICECandidate: Codable, Sendable {
    public let sdpMid: String?
    public let sdpMLineIndex: Int32
    public let candidate: String

    public init(sdpMid: String?, sdpMLineIndex: Int32, candidate: String) {
        self.sdpMid = sdpMid
        self.sdpMLineIndex = sdpMLineIndex
        self.candidate = candidate
    }
}

public struct SignalingMessage: Codable, Sendable {
    public let type: SignalingMessageType
    public let sender: String
    public let target: String?
    public let room: String?
    public let sdp: String?
    public let candidate: ICECandidate?
    public let members: [String]?

    public init(
        type: SignalingMessageType,
        sender: String,
        target: String?,
        room: String?,
        sdp: String?,
        candidate: ICECandidate?,
        members: [String]?
    ) {
        self.type = type
        self.sender = sender
        self.target = target
        self.room = room
        self.sdp = sdp
        self.candidate = candidate
        self.members = members
    }
}

public extension SignalingMessage {
    static func join(sender: String, room: String) -> Self {
        SignalingMessage(
            type: .join,
            sender: sender,
            target: nil,
            room: room,
            sdp: nil,
            candidate: nil,
            members: nil
        )
    }

    static func leave(sender: String, room: String?) -> Self {
        SignalingMessage(
            type: .leave,
            sender: sender,
            target: nil,
            room: room,
            sdp: nil,
            candidate: nil,
            members: nil
        )
    }

    static func offer(sender: String, target: String, room: String, sdp: String) -> Self {
        SignalingMessage(
            type: .offer,
            sender: sender,
            target: target,
            room: room,
            sdp: sdp,
            candidate: nil,
            members: nil
        )
    }

    static func answer(sender: String, target: String, room: String, sdp: String) -> Self {
        SignalingMessage(
            type: .answer,
            sender: sender,
            target: target,
            room: room,
            sdp: sdp,
            candidate: nil,
            members: nil
        )
    }

    static func iceCandidate(sender: String, target: String, room: String, candidate: ICECandidate) -> Self {
        SignalingMessage(
            type: .iceCandidate,
            sender: sender,
            target: target,
            room: room,
            sdp: nil,
            candidate: candidate,
            members: nil
        )
    }

    static func error(sender: String = "server", target: String? = nil, room: String? = nil, message: String) -> Self {
        SignalingMessage(
            type: .error,
            sender: sender,
            target: target,
            room: room,
            sdp: message,
            candidate: nil,
            members: nil
        )
    }

    static func peerJoined(sender: String, target: String? = nil, room: String, members: [String]? = nil) -> Self {
        SignalingMessage(
            type: .peerJoined,
            sender: sender,
            target: target,
            room: room,
            sdp: nil,
            candidate: nil,
            members: members
        )
    }

    static func peerLeft(sender: String, target: String? = nil, room: String, members: [String]? = nil) -> Self {
        SignalingMessage(
            type: .peerLeft,
            sender: sender,
            target: target,
            room: room,
            sdp: nil,
            candidate: nil,
            members: members
        )
    }
}
