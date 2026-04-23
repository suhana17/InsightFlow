//
//  TranscriptView.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 3/31/26.
//

import SwiftUI

struct TranscriptView: View {
    @ObservedObject var speech: SpeechManager
    
    @Environment(\.colorScheme) var colorScheme

    var discussions: [(String, String, String)]
    
    var body: some View {
        VStack(spacing: 30) {

            Image(colorScheme == .light ? "BlackIcon" : "WhiteIcon")
                .resizable()
                .frame(width: 150, height: 150)

            ScrollView {

                if speech.isProcessing {
                    VStack {
                        ProgressView()
                        Text("Processing...")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
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
