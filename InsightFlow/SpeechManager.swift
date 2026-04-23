//
//  SpeechManager.swift
//  InsightFlow
//

import Foundation
import Speech
import AVFoundation
import Combine

class SpeechManager: NSObject, ObservableObject {

    @Published var transcriptText = ""
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var summary: String
    @Published var discussions: [(String, String, String)] = []

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioFileURL: URL?
    private var recordingFile: AVAudioFile?

 
    init(transcriptText: String = "",
         isRecording: Bool = false,
         isProcessing: Bool = false,
         summary: String = "",
         discussions: [(String, String, String)] = [],
         recognitionRequest: SFSpeechAudioBufferRecognitionRequest? = nil,
         recognitionTask: SFSpeechRecognitionTask? = nil,
         audioFileURL: URL? = nil) {
        self.transcriptText = transcriptText
        self.isRecording = isRecording
        self.isProcessing = isProcessing
        self.summary = summary
        self.discussions = discussions
        self.recognitionRequest = recognitionRequest
        self.recognitionTask = recognitionTask
        self.audioFileURL = audioFileURL
        super.init()
    }

    // MARK: Permissions
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                print("Speech recognition not authorized: \(status.rawValue)")
            }
        }
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone permission not granted")
            }
        }
        #endif
    }

    // MARK: Recording Control
    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    // MARK: Start Recording
    func startRecording() {
        // Reset state
        DispatchQueue.main.async {
            self.summary = ""
            self.transcriptText = ""
            self.isProcessing = false
            self.isRecording = true
        }

        #if os(iOS)
        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
        #endif

        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Create recognition request and enable partial results for live updates
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device if available (optional)
        if #available(iOS 13, macOS 10.15, *) {
            request.requiresOnDeviceRecognition = false
        }
        recognitionRequest = request

        // Prepare input and format
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // Prepare audio file for Whisper
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("speech.wav")
        audioFileURL = fileURL
        do {
            let file = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            recordingFile = file
        } catch {
            print("Failed to create AVAudioFile: \(error)")
            recordingFile = nil
        }

        // Install tap to feed both Speech and file writer
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            if let file = self.recordingFile {
                do {
                    try file.write(from: buffer)
                } catch {
                    print("Audio file write error: \(error)")
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }

        // Start recognition task after engine is running
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.transcriptText = result.bestTranscription.formattedString
                }
                if result.isFinal {
                    // Let the task finish naturally; handoff to Whisper happens in stopRecording
                }
            }
            if let error = error {
                // This will also be invoked with cancellation if we cancel explicitly.
                print("Recognition error: \(error)")
            }
        }
    }

    // MARK: Stop Recording
    func stopRecording() {
        // Stop sending audio to the recognizer first
        audioEngine.inputNode.removeTap(onBus: 0)

        // Signal end of audio to recognition request
        recognitionRequest?.endAudio()

        // Stop the engine
        audioEngine.stop()

        // Close the file writer
        recordingFile = nil

        // Update UI state
        DispatchQueue.main.async {
            self.isRecording = false
            self.isProcessing = true
        }

        // Do NOT cancel the recognitionTask here; allow it to finish processing the buffered audio.

        // Start processing Whisper → GPT
        sendToWhisper()
    }

    // MARK: Whisper
    func sendToWhisper() {
        guard let audioFileURL else {
            print("Audio file URL is nil")
            DispatchQueue.main.async { self.isProcessing = false }
            return
        }

        guard let url = URL(string: "https://ai-backend-production-f176.up.railway.app/transcribe") else {
            print("Invalid backend URL")
            DispatchQueue.main.async {
                self.summary = "Invalid server URL."
                self.isProcessing = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var bodyData = Data()

        do {
            let audioData = try Data(contentsOf: audioFileURL)

            bodyData.append("--\(boundary)\r\n".data(using: .utf8)!)
            bodyData.append("Content-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\n".data(using: .utf8)!)
            bodyData.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            bodyData.append(audioData)
            bodyData.append("\r\n".data(using: .utf8)!)
            bodyData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        } catch {
            print("Failed loading audio data: \(error)")
            DispatchQueue.main.async {
                self.summary = "Failed to load audio data."
                self.isProcessing = false
            }
            return
        }

        URLSession.shared.uploadTask(with: request, from: bodyData) { data, _, error in
            if let error = error {
                print("Transcription request failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.summary = "Transcription failed."
                    self.isProcessing = false
                }
                return
            }

            guard let data = data else {
                print("No transcription data")
                DispatchQueue.main.async {
                    self.summary = "No transcription data received."
                    self.isProcessing = false
                }
                return
            }

            print("Transcription raw response:", String(data: data, encoding: .utf8) ?? "")

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let text = json?["text"] as? String, !text.isEmpty {
                    DispatchQueue.main.async {
                        self.transcriptText = text
                    }
                    self.summarizeTranscript(text)
                } else {
                    let fallback = String(data: data, encoding: .utf8) ?? ""
                    print("Transcription response missing text: \(fallback)")
                    DispatchQueue.main.async {
                        self.summary = "Transcription returned unexpected format."
                        self.isProcessing = false
                    }
                }
            } catch {
                print("Transcription parsing error:", error)
                DispatchQueue.main.async {
                    self.summary = "Transcription parsing error."
                    self.isProcessing = false
                }
            }
        }.resume()
    }
    
    func generateTitle(from text: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://ai-backend-production-f176.up.railway.app/title") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["text": text]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let title = json["title"] as? String {
                    completion(title.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    func summarizeTranscript(_ transcript: String) {
        guard let url = URL(string: "https://ai-backend-production-f176.up.railway.app/chat/anthropic") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["prompt": transcript] // ONLY send transcript
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Request failed:", error.localizedDescription)
                DispatchQueue.main.async {
                    self.summary = "Summary generation failed."
                    self.isProcessing = false
                }
                return
            }
            
            if let data = data {
                print("RAW RESPONSE:", String(data: data, encoding: .utf8) ?? "")
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.summary = "No data received."
                    self.isProcessing = false
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    
                    DispatchQueue.main.async {
                        self.summary = text
                    }
                    
                    // Generate title (you should also move this to backend later)
                    self.generateTitle(from: transcript) { title in
                        DispatchQueue.main.async {
                            let finalTitle = title ?? "Untitled"
                            self.discussions.append((finalTitle, self.transcriptText, text))
                            self.isProcessing = false
                        }
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        self.summary = "Unexpected response format."
                        self.isProcessing = false
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.summary = "Parsing error."
                    self.isProcessing = false
                }
            }
            
        }.resume()
    }
}

