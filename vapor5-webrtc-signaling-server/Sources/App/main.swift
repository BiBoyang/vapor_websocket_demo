import Vapor

@main
enum SignalingServer {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = 8080
        defer {
            Task {
                try? await app.asyncShutdown()
            }
        }

        let roomManager = RoomManager()
        let signalingService = SignalingService(roomManager: roomManager)
        let signalingHandler = SignalingWebSocketHandler(signalingService: signalingService)
        registerRoutes(on: app, handler: signalingHandler)
        try await app.execute()
    }
}
