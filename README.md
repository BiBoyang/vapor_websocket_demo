# vapor_websocket_demo


A minimal WebRTC signaling server built with Vapor(swift) and WebSocket.

## Tech Stack

- Swift `5.9` (`swift-tools-version: 5.9`)
- Vapor `4.92.0+`
- WebSocket via Vapor's built-in WebSocket support
- Swift Package Manager
- macOS `13+`

## Features

- WebSocket signaling endpoint at `/signal`
- Health check endpoint at `/health`
- Debug room list endpoint at `/rooms`
- Basic room-based signaling for WebRTC-style messages
- CORS enabled for local testing

## Endpoints

- `GET /`
- `GET /health`
- `GET /rooms`
- `WS /signal`

## Run Locally

```bash
swift build
swift run SignalingServer
```

Default local addresses:

- `http://127.0.0.1:8080`
- `ws://127.0.0.1:8080/signal`

## Project Structure

```text
Sources/SignalingServer/
  main.swift
  configure.swift
  routes.swift
```

## Notes

- This project is intended as a lightweight signaling test server.
- It is suitable for local WebRTC signaling experiments, not production deployment.


```
  A                           Signaling Server                           B
  |                                  |                                  |
  |---- join room ------------------>|                                  |
  |                                  |<----------------- join room -----|
  |                                  |---- peerJoined ----------------->|
  |                                  |<---------------- peerJoined -----|
  |                                  |                                  |
  |---- offer ---------------------->|                                  |
  |                                  |-------------- offer ----------->|
  |                                  |                                  |
  |                                  |<------------- answer -----------|
  |<--- answer ----------------------|                                  |
  |                                  |                                  |
  |---- iceCandidate --------------->|                                  |
  |                                  |---------- iceCandidate -------->|
  |                                  |                                  |
  |                                  |<--------- iceCandidate ---------|
  |<--- iceCandidate ----------------|                                  |
  |                                  |                                  |
  
  ```