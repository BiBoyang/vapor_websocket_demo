import Vapor
import WebSocketKit

actor RoomManager {
    private let maxParticipantsPerRoom = 2
    private var rooms: [String: Set<String>] = [:]
    private var connections: [String: [String: WebSocket]] = [:]
    private var userIdToRoom: [String: String] = [:]

    func joinRoom(roomId: String, userId: String, socket: WebSocket) -> Result<[String], RoomJoinError> {
        var members = rooms[roomId] ?? Set()
        let existingMembers = Array(members).sorted()

        if !members.contains(userId), members.count >= maxParticipantsPerRoom {
            return .failure(.roomFull)
        }

        members.insert(userId)
        rooms[roomId] = members

        if connections[roomId] == nil {
            connections[roomId] = [:]
        }

        connections[roomId]?[userId] = socket
        userIdToRoom[userId] = roomId

        return .success(existingMembers)
    }

    func leaveRoom(userId: String) -> String? {
        guard let roomId = userIdToRoom[userId] else {
            return nil
        }

        rooms[roomId]?.remove(userId)
        connections[roomId]?.removeValue(forKey: userId)

        if connections[roomId]?.isEmpty == true {
            rooms.removeValue(forKey: roomId)
            connections.removeValue(forKey: roomId)
        }

        userIdToRoom.removeValue(forKey: userId)
        return roomId
    }

    func getSocket(roomId: String, userId: String) -> WebSocket? {
        connections[roomId]?[userId]
    }

    func contains(roomId: String, userId: String) -> Bool {
        rooms[roomId]?.contains(userId) == true
    }

    func members(in roomId: String) -> [String] {
        Array(rooms[roomId] ?? []).sorted()
    }

    func sockets(in roomId: String, excluding excludedUserId: String? = nil) -> [WebSocket] {
        guard let roomConnections = connections[roomId] else {
            return []
        }

        return roomConnections.compactMap { userId, socket in
            if let excludedUserId, excludedUserId == userId {
                return nil
            }
            return socket
        }
    }
}

enum RoomJoinError: Error {
    case roomFull
}
