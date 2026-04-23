//
//  ContentView.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 3/14/26.
//

import SwiftUI
import Speech
import AVFoundation

enum Tabs {
    case transcript, summary, list, search
}

struct ContentView: View {

    @State var selectedTab: Tabs = .transcript
    @State var searchString = ""
    @State var summary = ""
    @State var placeHolderTranscript = ""
    @State var discussions: [(String, String, String)] = []

    @StateObject private var speech: SpeechManager

    init() {
        _speech = StateObject(wrappedValue: SpeechManager(discussions: []))
    }

    var body: some View {
        #if os(iOS)
        iOSLayout
        #else
        macOSLayout
        #endif
    }

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("Transcript", systemImage: "text.bubble", value: .transcript) {
                TranscriptView(speech: speech, discussions: discussions)
            }

            Tab("Summary", systemImage: "text.redaction", value: .summary) {
                SummaryView(speech: speech)
            }

            Tab("List", systemImage: "list.bullet", value: .list) {
                ListView()
            }

            Tab(value: .search, role: .search) {
                NavigationStack {
                    List {
                        SearchView()
                    }
                    .navigationTitle("Search")
                    .searchable(text: $searchString)
                }
            }
        }
        .tabViewBottomAccessory {
            HStack {
                Spacer()
                Button(action: {
                    selectedTab = .transcript
                    speech.toggleRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(speech.isRecording ? Color.red : Color.blue)
                            .frame(width: 72, height: 72)
                            .shadow(color: (speech.isRecording ? Color.red : Color.blue).opacity(0.4), radius: 10, y: 4)

                        Image(systemName: speech.isRecording ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    #endif

    // MARK: - macOS Layout

    #if os(macOS)
    private var macOSLayout: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                Tab("Transcript", systemImage: "text.bubble", value: .transcript) {
                    TranscriptView(speech: speech, discussions: discussions)
                }

                Tab("Summary", systemImage: "text.redaction", value: .summary) {
                    SummaryView(speech: speech)
                }

                Tab("List", systemImage: "list.bullet", value: .list) {
                    ListView()
                }

                Tab("Search", systemImage: "magnifyingglass", value: .search) {
                    NavigationStack {
                        List {
                            SearchView()
                        }
                        .navigationTitle("Search")
                        .searchable(text: $searchString)
                    }
                }
            }
            .tabViewStyle(.automatic)

            HStack {
                Spacer()
                Button {
                    selectedTab = .transcript
                    speech.toggleRecording()
                } label: {
                    Image(systemName: speech.isRecording ? "mic.slash.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(speech.isRecording ? Color.red : Color.blue)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 75, height: 75)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                        )
                        .overlay(
                            // Subtle top-catch specular highlight, like glass
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.55),
                                            .white.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.75
                                )
                        )
                        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
                        .shadow(color: .black.opacity(0.07), radius: 2,  x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: .command)
                .help(speech.isRecording ? "Stop Recording (⌘R)" : "Start Recording (⌘R)")
                Spacer()
            }
            .padding(.vertical, 16)
            .background(.bar)
        }
    }
    #endif
}

#Preview {
    ContentView()
}
