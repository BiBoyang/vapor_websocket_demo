# AGENTS.md

## Purpose

This repository is a Vapor-based WebRTC signaling server. The primary goal is to provide a clean, typed, maintainable signaling path for a Swift iOS client during initial 1:1 WebRTC session setup.

## Working Rules

- Keep signaling responsibilities narrow. This server relays control-plane messages only.
- Do not implement media relay, SFU logic, or TURN behavior here.
- Prefer simple in-memory state for version 1.
- Keep the first working version limited to one room with at most two peers.
- Do not trust client-provided sender identity. Derive identity from the WebSocket handshake.
- Use typed `Codable` models for signaling messages. Avoid `[String: Any]`-style payloads.

## Architecture Direction

The codebase should converge toward three layers:

1. Transport
   Vapor WebSocket route handling, connection lifecycle, ping and pong.
2. Protocol
   Shared signaling envelope and payload models used by both server and iOS client.
3. Application
   Room membership, authorization checks, routing, and disconnect cleanup.

The long-term server structure should look like:

```text
Sources/App/
  main.swift
  configure.swift
  routes.swift
  WebSocket/
    SignalingWebSocketController.swift
  Signaling/
    SignalingService.swift
    MessageRouter.swift
    ConnectionRegistry.swift
    RoomRegistry.swift
    Authenticator.swift
  Models/
    ClientConnection.swift
    RoomState.swift
```

## Current State

- The current prototype lives mostly in `Sources/App/main.swift`.
- That is acceptable as a temporary spike.
- New work should reduce the amount of protocol and state logic inside `main.swift`, not increase it.

## Protocol Contract

Version 1 should support these signaling message types:

- `join`
- `peerJoined`
- `peerLeft`
- `offer`
- `answer`
- `iceCandidate`
- `hangup`
- `ping`
- `pong`
- `error`

Required message rules:

- `offer`, `answer`, and `iceCandidate` must include `roomID` and `to`.
- A sender must already be authenticated and present in the room.
- The target peer must exist in the same room.
- Invalid messages should produce a typed `error` response.

## Shared Code

Shared code between the Vapor server and the iOS app should be limited to:

- signal envelope models
- payload models
- signal type enum
- error payloads
- JSON codec utilities

Do not try to share:

- Vapor route handlers
- socket lifecycle code
- room registry implementation
- WebRTC peer connection code

## Concurrency

- Use Swift Concurrency and actors for mutable shared state.
- Prefer actor-isolated registries over manual locking.
- `ConnectionRegistry` and `RoomRegistry` are expected to become actors.

## Authentication

- Handshake-time auth is required even in early versions.
- Local development may use a test token strategy.
- The server must override any client-provided sender field with the authenticated identity.

## Logging

Log:

- connection open and close
- authenticated user ID
- room join and leave
- message type and routing target
- validation failures

Do not log full SDP bodies or full ICE candidate strings.

## Delivery Priorities

When adding features, prefer this order:

1. stable protocol models
2. room membership correctness
3. offer and answer relay
4. ICE candidate relay
5. disconnect cleanup
6. heartbeat
7. reconnection

## Non-Goals For Version 1

- Redis-backed distributed state
- multiparty conferencing
- persistent call history
- offline message queue
- renegotiation-heavy session logic

## iOS Client Guidance

- Create the client as an Xcode iOS app project.
- Use SwiftUI for the initial test harness unless there is a strong reason not to.
- Add the shared signaling package to the Xcode project as a local package dependency.
- Keep the iOS app layered into `WebSocketClient`, `SignalingClient`, and `WebRTCSessionManager`.

## Reference Document

Detailed design guidance for this repository lives in:

- `docs/signaling-design.md`
