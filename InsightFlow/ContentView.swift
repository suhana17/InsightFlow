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
        // Initialize after self’s stored properties exist
        _speech = StateObject(wrappedValue: SpeechManager(discussions: []))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Transcript", systemImage: "text.bubble", value: .transcript) {
                TranscriptView(speech: speech, discussions: discussions)
            }
            
            Tab("Summary", systemImage: "text.redaction", value: .summary) {
                // Pass only the observed SpeechManager so updates propagate
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
            Button(action: {
                selectedTab = .transcript
                speech.toggleRecording()
            }) {
                
                Image(systemName: speech.isRecording ? "mic.slash.fill" : "mic.fill")
                    .resizable()
                    .padding()
                    .frame(width: speech.isRecording ? 65 : 57, height: 65)
                    .foregroundStyle(speech.isRecording ? Color.red : Color.blue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ContentView()
}
