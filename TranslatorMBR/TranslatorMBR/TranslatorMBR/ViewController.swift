import UIKit
import Speech
import AVFoundation
import NaturalLanguage

class ViewController: UIViewController {
    
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var translationLabel: UILabel!
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    var audioEngine = AVAudioEngine()
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    let synthesizer = AVSpeechSynthesizer()
    var favorites: [String] = []
    var history: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        requestSpeechPermissions()
        loadSavedData()
    }
    
    // Запрос разрешений
    func requestSpeechPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("Разрешение на распознавание речи получено")
            default:
                print("Распознавание речи недоступно")
            }
        }
    }
    
    // Автоопределение языка
    func detectLanguage(for text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let languageCode = recognizer.dominantLanguage?.rawValue {
            return languageCode
        }
        return "Неизвестный язык"
    }
    
    // Диктовка
    @IBAction func startDictation(_ sender: UIButton) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        } else {
            startListening()
        }
    }
    
    func startListening() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                self.inputTextView.text = recognizedText
            }
            if error != nil {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionTask = nil
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    // Перевод текста
    func translateText(_ text: String) -> String {
        // Пример с использованием локального словаря
        let translations = [
            "hello": "привет",
            "world": "мир"
        ]
        let words = text.lowercased().split(separator: " ")
        let translatedWords = words.map { translations[String($0)] ?? String($0) }
        return translatedWords.joined(separator: " ")
    }
    
    @IBAction func translate(_ sender: UIButton) {
        let text = inputTextView.text ?? ""
        let detectedLanguage = detectLanguage(for: text)
        let translatedText = translateText(text)
        translationLabel.text = "\(translatedText) (\(detectedLanguage))"
        
        // Сохранение в историю
        if !text.isEmpty {
            history.append(text)
            UserDefaults.standard.set(history, forKey: "History")
        }
    }
    
    // Озвучивание перевода
    @IBAction func speakTranslation(_ sender: UIButton) {
        let text = translationLabel.text ?? ""
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU") // Язык озвучивания
        synthesizer.speak(utterance)
    }
    
    // Добавление в избранное
    @IBAction func addToFavorites(_ sender: UIButton) {
        let text = translationLabel.text ?? ""
        if !text.isEmpty {
            favorites.append(text)
            UserDefaults.standard.set(favorites, forKey: "Favorites")
        }
    }
    
    // Загрузка сохраненных данных
    func loadSavedData() {
        favorites = UserDefaults.standard.stringArray(forKey: "Favorites") ?? []
        history = UserDefaults.standard.stringArray(forKey: "History") ?? []
    }
    
    // Переход в историю
    @IBAction func showHistory(_ sender: UIButton) {
        let historyVC = HistoryViewController()
        historyVC.history = history
        navigationController?.pushViewController(historyVC, animated: true)
    }
    
    // Переход в избранное
    @IBAction func showFavorites(_ sender: UIButton) {
        let favoritesVC = FavoritesViewController()
        favoritesVC.favorites = favorites
        navigationController?.pushViewController(favoritesVC, animated: true)
    }
}
