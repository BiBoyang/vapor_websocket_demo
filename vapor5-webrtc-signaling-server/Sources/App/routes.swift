import Vapor

func registerRoutes(on app: Application, handler: SignalingWebSocketHandler) {
    app.webSocket("signaling") { _, ws in
        handler.handle(ws)
    }

    app.get { _ in
        [
            "status": "ok",
            "message": "WebRTC signaling server is running",
            "websocket": "/signaling"
        ]
    }
}
