//
//  TranscriptView.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 3/31/26.
//

import SwiftUI

struct TranscriptView: View {
    @ObservedObject var speech: SpeechManager
    var discussions: [(String, String, String)]
    
    var body: some View {
        VStack(spacing: 30) {

            Text("InsightFlow")
                .font(.largeTitle)
                .fontWeight(.bold)

            ScrollView {

                if speech.isProcessing {
                    VStack {
                        ProgressView()
                        Text("Processing...")
                    }
                    .padding()
                } else {
                    // Drive directly from SpeechManager
                    Text(speech.transcriptText.isEmpty ? "Start speaking..." : speech.transcriptText)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

            }
            .frame(height: 300)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
        .onAppear {
            speech.requestPermissions()
        }
    }
}
