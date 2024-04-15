//
//  ViewController.swift
//  iReachYou
//
//  Created by Daniel Steven Espinosa on 4/13/24.
//

import UIKit
import AVKit
import Speech


class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var videoFile: UIButton!
    @IBOutlet weak var microphone: UIButton!
    @IBOutlet weak var cameraButton: UIButton!
    
   
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
        
    
    // Dictionary mapping words to dummy image URLs (replace with actual image data later)
    
    let signLanguageImages: [String: String] = [
        
        "hello": "hello.jpg",
        "how are you?": "How are you.jpg",
        "goodbye": "GoodBye.png",
        "i am fine": "I am fine.jpg",
        "nice to meet you": "Nice to Meet You.jpg",
        "no": "no.jpg",
        "yes": "yes.jpg",
        "what is your name?": "What is your name.jpg"
        
        // Add more words and corresponding image URLs as needed
        ]
    
    let signLanguageVideos: [String: String] = [
        "hello": "hello.mp4",
        "how are you?": "How are you?.mp4",
        "goodbye": "goodbye.mp4",
        "i am fine": "i am fine.mp4",
        "nice to meet you": "nice to meet you.mp4",
        "no": "no.mp4",
        "yes": "yes.mp4"
        
        // Add more words and corresponding video filenames as needed
             
         ]
        
        
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        speechRecognizer.delegate = self
        requestSpeechAuthorization()
     
    }
    
    
    
    func requestSpeechAuthorization() {
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            DispatchQueue.main.async {
                
                if authStatus == .authorized {
                    self.microphone.isEnabled = true
                }
            }
        }
    }
    
        
    func loadImage(from imagePath: String) {
        
        if let image = UIImage(named: imagePath) {
            // Fade in the image view with smooth transition
            UIView.animate(withDuration: 0.5){
                self.imageView.alpha = 1.0
                self.imageView.image = image
            }
            
        } else {
            print("Image not found at path: \(imagePath)")
            // You can show an error message or placeholder image here if the image is not found
        }
    }
    
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        
        if let text = textField.text?.lowercased(), let imageURL = signLanguageImages[text] {
            
            // Load and display image with a delay and smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3){
                self.loadImage(from: imageURL)
            }
            
        } else {
            
            imageView.alpha = 0 // Fade out the image view if no image found
        }
    }
    
    // IBAction for the video button
    
    @IBAction func videoButtonTapped(_ sender: UIButton) {
        
        // Display video showing sign language for the word in the text field
        
        if let word = textField.text?.lowercased(), let videoFilename = signLanguageVideos[word] {
            
            // Remove the file extension from the video filename
                let fileNameWithoutExtension = (videoFilename as NSString).deletingPathExtension
               
            // Check if the video file exists in the "videos" folder of your app bundle
               if let path = Bundle.main.path(forResource: fileNameWithoutExtension, ofType: "mp4", inDirectory: "videos") {
                   
                       let player = AVPlayer(url: URL(fileURLWithPath: path))
                   
                       let playerViewController = AVPlayerViewController()
                       playerViewController.player = player
                   
                       present(playerViewController, animated: true) {
                           player.play()
                       }
                    }
            else {
                print("Video file not found:", videoFilename)
            }
        }
    }
    
    // Add a property to keep track of whether recording is in progress
    var isRecording = false
    
    @IBAction func microphoneButtonTapped(_ sender: UIButton) {
        
        if isRecording {
            stopRecording()
            isRecording = false
            
            } else {
            
                startRecording()
                isRecording = true
            }
        
    }
    
    // Declare a timer property
    var silenceTimer: Timer?

    
    func startRecording() {
        
        if recognitionTask != nil {  // Cancel the previous task if it's running
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup error: \(error)")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a recognition request")
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            
            var isFinal = false
            if let result = result {
                self.textField.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start error: \(error)")
        }
        
        startSilenceTimer()
    }
    
    // Start a timer to monitor for silence
    func startSilenceTimer() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            // Stop recording if no speech is detected within 3 seconds
            self?.stopRecording()
        }
    }

    // Stop recording audio
    func stopRecording() {
        
        // Stop the silence timer
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Stop audio engine and recognition task
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        
        // Get the text from the text field
        guard let word = textField.text?.lowercased() else {
            print("No word recognized")
            return
        }
        
        // Check if the word exists in the dictionary
        if let imageURL = signLanguageImages[word] {
            // Update image view with the corresponding image
            loadImage(from: imageURL)
        } else {
            // Word not found in dictionary, handle gracefully
            print("Image not found for word: \(word)")
            // Optionally, display a default image or error message
        }
        
        // Reset the text field
        textField.text = nil
        
    }
    
    
}
    
    




