//
//  SummaryView.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 3/31/26.
//

import SwiftUI

struct SummaryView: View {
    @ObservedObject var speech: SpeechManager

    var body: some View {
        VStack {
            Text("Summary")
                .font(.largeTitle)
                .fontWeight(.bold)

            if !speech.summary.isEmpty {
                ScrollView {
                    Text(speech.summary)
                        .font(.title3)
                        .lineSpacing(10)
                        .padding()
                }
            }
        }
    }
}
