import UIKit
import Speech
import AVFoundation
import NaturalLanguage

class ViewController: UIViewController {
    
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var translationLabel: UITextView!
    
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
    var isListening = false // Переменная для отслеживания состояния диктовки

    
    let synthesizer = AVSpeechSynthesizer()
    var favorites: [TranslationRecord] = []

    var history: [TranslationRecord] = []

    
    let lingvaTranslateBaseURL = "https://lingva.ml/api/v1"

    override func viewDidLoad() {
        super.viewDidLoad()
   
           inputTextView.delegate = self
        loadSavedData()
        inputTextView.delegate = self
        sourceLanguagePicker.delegate = self
        sourceLanguagePicker.dataSource = self
        targetLanguagePicker.delegate = self
        targetLanguagePicker.dataSource = self
      
        
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
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            try audioSession.setPreferredSampleRate(16000)
            try audioSession.setPreferredInputNumberOfChannels(1)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }

    func startListening() {
        setupAudioSession() // Настроить аудио-сессию перед началом записи

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.inputFormat(forBus: 0)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, time) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            print("Started listening...")
        } catch {
            print("Audio engine couldn't start: \(error.localizedDescription)")
        }

        recognitionTask = SFSpeechRecognizer()?.recognitionTask(with: recognitionRequest!) { result, error in
            if let result = result {
                self.inputTextView.text = result.bestTranscription.formattedString
            }

            if let error = error {
                print("Error during dictation: \(error.localizedDescription)")
                self.stopListening()
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
        print("Stopped listening...")
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
                    self.saveHistoryRecord(
                        sourceText: text,
                        translatedText: translatedText,
                        sourceLang: self.selectedSourceLang,
                        targetLang: self.selectedTargetLang
                    )
                } else {
                    self.translationLabel.text = "Ошибка перевода"
                }
            }
        }

    }

    @IBAction func speakTranslation(_ sender: UIButton) {
        let text = translationLabel.text ?? ""
        
        // Если synthesizer уже говорит, останавливаем его
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate) // Немедленно прекращаем воспроизведение
            return
        }
        
        // Создаем объект AVSpeechUtterance
        let utterance = AVSpeechUtterance(string: text)
        
        // Определение языка озвучивания в зависимости от выбранного языка
        let languageCode = selectedTargetLang // предполагаем, что selectedTargetLang содержит код целевого языка
        
        switch languageCode {
        case "ru":
            utterance.voice = AVSpeechSynthesisVoice(language: "ru-RU") // Русский
        case "en":
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Английский
        case "es":
            utterance.voice = AVSpeechSynthesisVoice(language: "es-ES") // Испанский
        case "fr":
            utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR") // Французский
        case "de":
            utterance.voice = AVSpeechSynthesisVoice(language: "de-DE") // Немецкий
        case "it":
            utterance.voice = AVSpeechSynthesisVoice(language: "it-IT") // Итальянский
        case "zh":
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN") // Китайский (упрощенный)
        case "ja":
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP") // Японский
        case "ko":
            utterance.voice = AVSpeechSynthesisVoice(language: "ko-KR") // Корейский
        case "ar":
            utterance.voice = AVSpeechSynthesisVoice(language: "ar-SA") // Арабский
        default:
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Английский по умолчанию
        }
        
        // Запуск озвучивания
        synthesizer.speak(utterance)
    }


    
    // Добавление в избранное
    @IBAction func addToFavorites(_ sender: UIButton) {
        let text = inputTextView.text ?? ""
        let translation = translationLabel.text ?? ""
        
        if !text.isEmpty && !translation.isEmpty {
            let record = TranslationRecord(
                sourceText: text,           // Поменяли местами
                translatedText: translation, // Поменяли местами
                sourceLanguage: selectedSourceLang,
                targetLanguage: selectedTargetLang
            )
            
            favorites.append(record)
            saveFavorites()
        }
    }


    
    
    @IBAction func showHistory(_ sender: UIButton) {
        let historyVC = storyboard?.instantiateViewController(withIdentifier: "HistoryViewController") as! HistoryViewController
        historyVC.history = history
        
        // Устанавливаем замыкание для выбора записи из истории
        historyVC.didSelectHistoryRecord = { [weak self] selectedRecord in
            guard let self = self else { return }
            
            let sourceLanguages = Array(self.languages.keys)
            let targetLanguages = Array(self.languages.keys)
            
            // Устанавливаем выбранные языки и текст
            self.sourceLanguagePicker.selectRow(sourceLanguages.firstIndex(of: selectedRecord.sourceLanguage) ?? 0, inComponent: 0, animated: true)
            self.targetLanguagePicker.selectRow(targetLanguages.firstIndex(of: selectedRecord.targetLanguage) ?? 0, inComponent: 0, animated: true)
            self.inputTextView.text = selectedRecord.sourceText
            self.translationLabel.text = selectedRecord.translatedText
        }
        
        // Настройка отображения как модальное окно
        if let sheet = historyVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()] // Высоты окна
            sheet.prefersGrabberVisible = true // Видимость полосы захвата
        }
        
        present(historyVC, animated: true)
    }





    @IBAction func showFavorites(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if let favoritesVC = storyboard.instantiateViewController(withIdentifier: "FavoritesViewController") as? FavoritesViewController {
            favoritesVC.favorites = favorites // Передача избранного
            favoritesVC.languages = languages // Передача словаря языков
            
            // Устанавливаем замыкание для выбора записи из избранного
            favoritesVC.didSelectFavRecord = { [weak self] selectedRecord in
                guard let self = self else { return }
                
                let sourceLanguages = Array(self.languages.keys)
                let targetLanguages = Array(self.languages.keys)
                
                // Устанавливаем выбранные языки и текст
                self.sourceLanguagePicker.selectRow(sourceLanguages.firstIndex(of: selectedRecord.sourceLanguage) ?? 0, inComponent: 0, animated: true)
                self.targetLanguagePicker.selectRow(targetLanguages.firstIndex(of: selectedRecord.targetLanguage) ?? 0, inComponent: 0, animated: true)
                self.inputTextView.text = selectedRecord.sourceText
                self.translationLabel.text = selectedRecord.translatedText
            }
            
            // Настройка отображения как модальное окно
            if let sheet = favoritesVC.sheetPresentationController {
                sheet.detents = [.medium(), .large()] // Высоты окна
                sheet.prefersGrabberVisible = true // Видимость полосы захвата
            }
            
            present(favoritesVC, animated: true)
        }
    }




    
    func saveHistoryRecord(sourceText: String, translatedText: String, sourceLang: String, targetLang: String) {
        // Создание объекта с правильным порядком параметров
        let record = TranslationRecord(
            sourceText: sourceText,         // Поменяли местами
            translatedText: translatedText, // Поменяли местами
            sourceLanguage: sourceLang,
            targetLanguage: targetLang
        )
        
        history.append(record)
        
        // Сохранение в UserDefaults
        let encodedHistory = history.compactMap { try? JSONEncoder().encode($0) }
        UserDefaults.standard.set(encodedHistory, forKey: "History")
    }




    func loadHistory() {
        if let savedHistory = UserDefaults.standard.array(forKey: "History") as? [Data] {
            history = savedHistory.compactMap { try? JSONDecoder().decode(TranslationRecord.self, from: $0) }
        }
    }

    func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "Favorites")
        }
    }
    
    func loadFavorites() {
        if let savedFavorites = UserDefaults.standard.array(forKey: "Favorites") as? [Data] {
            favorites = savedFavorites.compactMap { try? JSONDecoder().decode(TranslationRecord.self, from: $0) }
        }
    }


    func loadSavedData() {
        if let historyData = UserDefaults.standard.data(forKey: "History"),
           let savedHistory = try? JSONDecoder().decode([TranslationRecord].self, from: historyData) {
            history = savedHistory
        }
        
        if let favoritesData = UserDefaults.standard.data(forKey: "Favorites"),
           let savedFavorites = try? JSONDecoder().decode([TranslationRecord].self, from: favoritesData) {
            favorites = savedFavorites
        }
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



extension ViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        // Прекращаем озвучивание, если текст изменился
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}


