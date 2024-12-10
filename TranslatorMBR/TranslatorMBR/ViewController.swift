import UIKit
import Speech
import AVFoundation
import NaturalLanguage

class ViewController: UIViewController {
    
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var translationLabel: UILabel!
    
    @IBOutlet weak var sourceLanguagePicker: UIPickerView!
    @IBOutlet weak var targetLanguagePicker: UIPickerView!

    
    let languages: [String: String] = [
        "en": "English",
        "ru": "Russian",
        "es": "Spanish",
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "zh": "Chinese",
            "ja": "Japanese",
            "ko": "Korean",
            "ar": "Arabic"
    ]

    var selectedSourceLang = "en" // Язык по умолчанию
    var selectedTargetLang = "ru" // Язык по умолчанию

    
    
    
    
    
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    var audioEngine = AVAudioEngine()
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    let synthesizer = AVSpeechSynthesizer()
    var favorites: [String] = []
    var history: [String] = []
    
    let lingvaTranslateBaseURL = "https://lingva.ml/api/v1"


    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sourceLanguagePicker.delegate = self
        sourceLanguagePicker.dataSource = self
        
        targetLanguagePicker.delegate = self
        targetLanguagePicker.dataSource = self
        
        // Устанавливаем начальные значения
        if let sourceIndex = Array(languages.keys).firstIndex(of: selectedSourceLang) {
            sourceLanguagePicker.selectRow(sourceIndex, inComponent: 0, animated: false)
        }
        if let targetIndex = Array(languages.keys).firstIndex(of: selectedTargetLang) {
            targetLanguagePicker.selectRow(targetIndex, inComponent: 0, animated: false)
        }
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
    
    // Перевод текста через LibreTranslate API
    func translateText(_ text: String, from sourceLang: String, to targetLang: String, completion: @escaping (String?) -> Void) {
        guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("Ошибка кодирования текста")
            completion(nil)
            return
        }
        
        let urlString = "\(lingvaTranslateBaseURL)/\(sourceLang)/\(targetLang)/\(encodedText)"
        guard let url = URL(string: urlString) else {
            print("Ошибка создания URL")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Ошибка запроса: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Неверный код ответа сервера")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("Пустой ответ сервера")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let translatedText = json["translation"] as? String {
                    completion(translatedText)
                } else {
                    print("Ошибка декодирования JSON")
                    completion(nil)
                }
            } catch {
                print("Ошибка декодирования ответа сервера: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }


    
    // Автоопределение языка через LibreTranslate API
    func detectLanguage(for text: String, completion: @escaping (String?) -> Void) {
        translateText(text, from: "auto", to: "en") { translatedText in
            // Lingva Translate автоматически определяет язык, но его нужно уточнить по контексту
            completion("auto") // API не возвращает код языка
        }
    }


    @IBAction func translate(_ sender: UIButton) {
        let text = inputTextView.text ?? ""
        if text.isEmpty {
            translationLabel.text = "Введите текст для перевода"
            return
        }
        
        translateText(text, from: selectedSourceLang, to: selectedTargetLang) { translatedText in
            DispatchQueue.main.async {
                if let translatedText = translatedText {
                    self.translationLabel.text = translatedText
                    
                    // Сохранение в историю
                    self.history.append("\(self.selectedSourceLang) -> \(self.selectedTargetLang): \(text)")
                    UserDefaults.standard.set(self.history, forKey: "History")
                } else {
                    self.translationLabel.text = "Ошибка перевода"
                }
            }
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
    
    
    @IBAction func showHistory(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let historyVC = storyboard.instantiateViewController(withIdentifier: "HistoryViewController") as? HistoryViewController {
            present(historyVC, animated: true, completion: nil)
        }
    }


    @IBAction func showFavorites(_ sender: UIButton) {
        let favoritesVC = storyboard?.instantiateViewController(withIdentifier: "FavoritesViewController") as! FavoritesViewController
        favoritesVC.favorites = favorites // Передача данных
        
        if let sheet = favoritesVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()] // Уровни высоты
            sheet.prefersGrabberVisible = true // Полоска для захвата
        }
        present(favoritesVC, animated: true)
    }

    
    
    // Загрузка сохраненных данных
    func loadSavedData() {
        favorites = UserDefaults.standard.stringArray(forKey: "Favorites") ?? []
        history = UserDefaults.standard.stringArray(forKey: "History") ?? []
    }
}

// Модели для API
struct TranslationResponse: Codable {
    let translatedText: String
}

struct DetectedLanguage: Codable {
    let language: String
    let confidence: Double
}


extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return languages.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let languageName = Array(languages.values)[row]
        return languageName
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedLanguageCode = Array(languages.keys)[row]
        
        if pickerView == sourceLanguagePicker {
            selectedSourceLang = selectedLanguageCode
        } else if pickerView == targetLanguagePicker {
            selectedTargetLang = selectedLanguageCode
        }
    }
}
