# WebRTC Signaling Design

## Goal

Build a WebSocket-based signaling server with Vapor for 1:1 WebRTC session setup, and a Swift iOS client for integration testing. The signaling layer only coordinates session setup and teardown. It does not carry media traffic.

## Scope

The first version should support:

- WebSocket connection setup
- user authentication at handshake time
- joining a room
- peer presence notification
- SDP `offer` and `answer` relay
- trickle ICE candidate relay
- hangup and leave handling
- heartbeat and stale connection cleanup
- minimal structured error responses

The first version should not support:

- media relay or SFU features
- distributed room state across multiple server nodes
- offline message delivery
- persistent call history
- renegotiation beyond the initial connection flow
- full multiparty conference semantics

## High-Level Architecture

Split the system into three layers.

### 1. Transport Layer

Responsible for:

- Vapor WebSocket route registration
- connection lifecycle
- ping and pong
- text frame send and receive
- handshake authentication

This layer should not contain room logic or SDP routing decisions.

### 2. Protocol Layer

Responsible for:

- shared `Codable` message models
- message envelope definition
- payload schemas for signaling events
- JSON encoder and decoder configuration

This layer should be shared between the Vapor server and the iOS client through a Swift Package.

### 3. Application Layer

Responsible for:

- connection registry
- room registry
- per-message authorization checks
- message routing
- peer presence state
- session teardown on disconnect

## Shared Package Layout

Create a shared Swift package, for example `SignalingShared`, and use it from both the Vapor app and the iOS app.

Recommended contents:

```text
SignalingShared/
  Package.swift
  Sources/
    SignalingShared/
      SignalEnvelope.swift
      SignalType.swift
      SignalPayloads.swift
      SignalError.swift
      Codec.swift
```

The shared package is the main place to reuse code. Do not try to reuse the WebSocket connection implementation itself across server and client.

## Message Envelope

Use a stable outer envelope and decode payload by `type`.

```swift
public struct SignalEnvelope: Codable, Sendable {
    public let id: UUID
    public let type: SignalType
    public let roomID: String?
    public let from: String?
    public let to: String?
    public let payload: PayloadContainer?
    public let timestamp: Date
}
```

Design notes:

- `id` is for tracing and deduplication
- `type` decides payload decoding
- `roomID` scopes the signaling context
- `from` should be derived from server-side auth, not trusted from the client
- `to` is used for direct peer relay
- `payload` carries type-specific data
- `timestamp` helps debugging and observability

## Message Types

The first version should support these types:

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

Optional later additions:

- `ring`
- `accept`
- `reject`
- `reconnect`
- `renegotiate`

## Payload Models

Recommended payload definitions:

```swift
public struct JoinPayload: Codable, Sendable {
    public let deviceID: String?
}

public struct OfferPayload: Codable, Sendable {
    public let sdp: String
}

public struct AnswerPayload: Codable, Sendable {
    public let sdp: String
}

public struct IceCandidatePayload: Codable, Sendable {
    public let sdpMid: String?
    public let sdpMLineIndex: Int32
    public let candidate: String
}

public struct HangupPayload: Codable, Sendable {
    public let reason: String?
}

public struct ErrorPayload: Codable, Sendable {
    public let code: String
    public let message: String
}
```

## Server State Model

Keep the initial in-memory state small and explicit.

### Connection

```swift
struct ClientConnection: Sendable {
    let connectionID: UUID
    let userID: String
    let roomID: String?
    let connectedAt: Date
    let lastSeenAt: Date
}
```

### Room

```swift
struct RoomState: Sendable {
    let roomID: String
    var participants: Set<String>
}
```

### Session

The first version can skip a dedicated session object if every room is limited to two peers. If later features need ringing, accept, reject, or reconnection, introduce:

```swift
enum CallState: String, Sendable {
    case idle
    case ringing
    case connecting
    case connected
    case ended
}
```

## Recommended Server Directory Structure

Refactor the current single-file implementation toward:

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

The current `main.swift` already mixes protocol, state, transport, and routing. That is acceptable as a prototype but should not remain the long-term shape.

## Concurrency Model

Use Swift Concurrency for shared mutable state.

Recommended actors:

- `ConnectionRegistry`
- `RoomRegistry`
- optionally `SessionRegistry`

Why:

- multiple WebSocket callbacks can arrive concurrently
- actor isolation keeps room membership consistent
- this avoids lock-heavy ad hoc synchronization

## Authentication

Do not trust client-sent `sender` or `from` fields.

Recommended approach:

1. Client obtains a token through an HTTP auth flow or a test-only signed token.
2. WebSocket handshake includes the token in `Authorization` or a query item.
3. Server validates the token and extracts `userID`.
4. Server fills or overrides the `from` field before routing messages.

For local testing, a temporary rule is acceptable:

- query: `ws://host/signaling?token=test-user-a`

But the decoding path should still be structured so production auth can replace it later without changing message routing.

## Routing Rules

Apply these validation rules on every signaling message:

- sender must be an authenticated connected user
- sender must belong to `roomID`
- target peer must belong to the same `roomID`
- `offer`, `answer`, and `iceCandidate` require both `roomID` and `to`
- room capacity should be capped at 2 for version 1

If validation fails, return an `error` envelope instead of silently ignoring the message.

## Room Strategy

For the first release, use a room-as-call model:

- one room represents one 1:1 call context
- maximum two participants
- server emits `peerJoined` when the second participant arrives
- server emits `peerLeft` or `hangup` when one side disconnects or exits

This is the cleanest path to a working WebRTC bootstrap flow.

## Expected Signaling Flow

1. User A connects to WebSocket.
2. User A sends `join(room-123)`.
3. User B connects to WebSocket.
4. User B sends `join(room-123)`.
5. Server notifies A and B with peer presence events.
6. User A creates an SDP offer and sends `offer`.
7. Server relays the offer to B.
8. User B sets remote description, creates an SDP answer, and sends `answer`.
9. Server relays the answer to A.
10. Both sides exchange multiple `iceCandidate` messages.
11. WebRTC peer connection reaches connected state.
12. Either side sends `hangup`, or disconnect cleanup triggers peer teardown.

## iOS Client Structure

Keep the iOS code layered as well.

```text
iOSApp/
  App/
  Features/
    Call/
      CallViewModel.swift
  Networking/
    WebSocketClient.swift
    SignalingClient.swift
  WebRTC/
    WebRTCSessionManager.swift
  Shared/
    imports SignalingShared
```

Responsibilities:

- `WebSocketClient`: raw socket lifecycle, send, receive, reconnect, ping
- `SignalingClient`: typed signaling API built on top of WebSocket
- `WebRTCSessionManager`: `RTCPeerConnection`, SDP creation, ICE handling
- UI or view model: user intent and state presentation

## Reuse Strategy

Code that should be shared:

- signaling envelope models
- payload models
- error payloads
- JSON codec configuration

Code that should not be shared:

- Vapor WebSocket route handling
- iOS `URLSessionWebSocketTask` implementation
- server-side room registry internals
- `RTCPeerConnection` integration

## Error Model

Every recoverable signaling failure should return a typed error.

Examples:

- `unauthorized`
- `invalid_message`
- `room_not_found`
- `room_full`
- `peer_not_found`
- `peer_not_in_room`
- `unsupported_message`

## Logging

Log at least:

- connection opened
- connection closed
- authenticated user ID
- room join and leave
- message type
- relay source and target
- validation failures
- heartbeat timeout

Avoid logging raw SDP or full ICE candidate strings. Log only summary information such as type, message ID, room ID, sender, target, and payload length.

## Heartbeat and Reconnect

The server should:

- send or expect periodic `ping` and `pong`
- update `lastSeenAt`
- close stale sockets after timeout

The iOS client should:

- detect socket closure
- reconnect with backoff
- rejoin room if appropriate
- regenerate signaling state if the call has not been fully established

The first version can implement reconnect without mid-call recovery.

## Redis

Your current package already includes Redis dependencies. Keep Redis out of version 1 unless you need multi-instance coordination. The in-memory actor-based implementation is simpler and better for getting the protocol right first.

Introduce Redis later only if you need:

- cross-instance room membership
- pub/sub for message relay
- ephemeral state externalization

## Testing Plan

Server tests:

- join room successfully
- reject third participant
- relay offer to target peer
- relay answer to target peer
- relay ICE candidate to target peer
- reject messages from a peer not in the room
- cleanup room membership on disconnect

Client integration tests:

- connect and join successfully
- receive peer presence event
- round-trip offer and answer over loopback or a local test server
- handle remote hangup

## Immediate Next Steps

1. Extract shared signaling models into a local Swift package.
2. Split the Vapor server out of `main.swift`.
3. Introduce `ConnectionRegistry` and `RoomRegistry` actors.
4. Replace client-provided sender identity with handshake-derived auth.
5. Build a small iOS test app that can connect, join, and drive one call flow.

## Xcode Recommendation

Yes, you should create an Xcode iOS project for the client side before starting the app implementation.

Recommended setup:

- create a new iOS App project in Xcode
- use Swift and SwiftUI
- target iOS 16 or later to align with the package manifest
- add the local `SignalingShared` package to the Xcode project
- add WebRTC dependency separately when you are ready to move from signaling-only UI to real peer connection work

If you want the fastest path, start with a blank SwiftUI app and only implement:

- connect or disconnect button
- room ID field
- join button
- log output panel
- call button to create and send an offer

That is enough to validate the signaling protocol before you integrate full audio and video capture.
