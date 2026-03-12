//
//  ContentView.swift
//  iOS_websocket_demo
//
//  Created by Boyang on 2026/3/13.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CallDemoViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    connectionSection
                    statusSection
                    signalingSection
                    logsSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("vapor_websocket_demo")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WebRTC Signaling Test Bench")
                .font(.title2.weight(.semibold))

            Text("This app targets the current Vapor prototype protocol and lets you verify WebSocket connectivity, room joins, and signaling relay before adding real WebRTC media handling.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Connection")

            labeledField("Server URL", text: $viewModel.serverURL, textInputAutocapitalization: .never)
            labeledField("User ID", text: $viewModel.userID, textInputAutocapitalization: .never)
            labeledField("Room ID", text: $viewModel.roomID, textInputAutocapitalization: .never)
            labeledField("Target User", text: $viewModel.targetUserID, textInputAutocapitalization: .never)

            HStack(spacing: 12) {
                Button("Connect") {
                    viewModel.connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.connectionState != .disconnected)

                Button("Disconnect") {
                    viewModel.disconnect()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.connectionState == .disconnected)
            }

            HStack(spacing: 12) {
                Button("Join Room") {
                    Task {
                        await viewModel.joinRoom()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.connectionState != .connected)

                Button("Leave Room") {
                    Task {
                        await viewModel.leaveRoom()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.connectionState != .connected)
            }

            VStack(alignment: .leading, spacing: 6) {
                statusRow(title: "Socket", value: viewModel.connectionState.rawValue.capitalized)
                statusRow(title: "Members", value: viewModel.members.isEmpty ? "None yet" : viewModel.members.joined(separator: ", "))
            }
            .font(.footnote)
        }
        .cardStyle()
    }

    private var signalingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Signaling")

            Text("SDP")
                .font(.headline)
            TextEditor(text: $viewModel.sdpText)
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            HStack(spacing: 12) {
                Button("Send Offer") {
                    Task {
                        await viewModel.sendOffer()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Send Answer") {
                    Task {
                        await viewModel.sendAnswer()
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("ICE Candidate")
                .font(.headline)
            TextEditor(text: $viewModel.candidateText)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

            Button("Send ICE Candidate") {
                Task {
                    await viewModel.sendCandidate()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .cardStyle()
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Session Status")

            VStack(alignment: .leading, spacing: 8) {
                statusRow(title: "Room", value: viewModel.currentRoomStatus)
                statusRow(title: "Peer", value: viewModel.peerID)
                statusRow(title: "Peer State", value: viewModel.peerState.rawValue.capitalized)
                statusRow(title: "Last Message", value: viewModel.lastIncomingMessage)
                statusRow(title: "Last Error", value: viewModel.lastServerError)
            }
            .font(.footnote)
        }
        .cardStyle()
    }

    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Logs")
                Spacer()
                Button("Clear") {
                    viewModel.logs = []
                }
                .font(.footnote.weight(.medium))
            }

            if viewModel.logs.isEmpty {
                Text("No events yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.logs, id: \.self) { line in
                        Text(line)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                }
            }
        }
        .cardStyle()
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        textInputAutocapitalization: TextInputAutocapitalization?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            TextField(title, text: text)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
            )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
