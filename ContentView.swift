import SwiftUI
import Speech
import AVFoundation
import UIKit



struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isListening = false
    @State private var cityName: String = ""
    @State private var hasSentCityName = false
    
    var body: some View {
        Color.black
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onTapGesture {
                if !isListening {
                    isListening = true
                    hasSentCityName = false
                    speechRecognizer.startListening { result in
                        if let firstWord = result.split(separator: " ").first, !firstWord.isEmpty {
                            let firstWordString = String(firstWord)
                            isListening = false
                            sendCityNameToServer(cityName: firstWordString)
                        }
                    }
                }
            }
    }
    
    func sendCityNameToServer(cityName: String) {
        guard var urlComponents = URLComponents(string: "http://127.0.0.1:5000/search") else { return }
        urlComponents.queryItems = [URLQueryItem(name: "city", value: cityName)]
        guard let url = urlComponents.url else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending city name: \(error)")
                return
            }
            print("City name sent successfully")
        }.resume()
    }
}

class SpeechRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        requestAuthorization()
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            switch authStatus {
            case .authorized:
                break
            case .denied, .restricted, .notDetermined:
                print("Speech recognition authorization denied.")
            @unknown default:
                break
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied.")
            }
        }
    }
    
    func startListening(completion: @escaping (String) -> Void) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            return
        }
        
        do {
            try startSession(completion: completion)
        } catch {
            print("Error starting session: \(error)")
        }
    }
    
    private func startSession(completion: @escaping (String) -> Void) throws {
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a recognition request")
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result, !result.bestTranscription.formattedString.isEmpty {
                let firstWord = result.bestTranscription.formattedString.split(separator: " ").first ?? ""
                completion(String(firstWord))
                self.stopListening()
            }
            
            if error != nil {
                self.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
    }
}
