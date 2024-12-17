import UIKit

class HistoryViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    // История будет содержать массив объектов TranslationRecord
    var history: [TranslationRecord] = []
    
    var didSelectHistoryRecord: ((TranslationRecord) -> Void)?

    
    // Словарь языков для отображения названий
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self

        loadHistory()
        // Регистрация стандартной ячейки
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
    }

    
    // Метод для загрузки истории из UserDefaults
    func loadHistory() {
        if let savedHistory = UserDefaults.standard.array(forKey: "History") as? [Data] {
            history = savedHistory.compactMap { try? JSONDecoder().decode(TranslationRecord.self, from: $0) }
        }
    }
}

extension HistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return history.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        let record = history[indexPath.row]
        
        // Формат текста
        let sourceLangName = languages[record.sourceLanguage] ?? "Unknown"
        let targetLangName = languages[record.targetLanguage] ?? "Unknown"
        cell.textLabel?.text = "\(record.sourceText) (\(sourceLangName)) -> \(record.translatedText) (\(targetLangName))"
        
        // Настройка шрифта и переносов
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.numberOfLines = 0
        
        return cell
    }

    
    // Свайп для удаления записи из истории
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            history.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // Обновление сохраненных данных
            let encodedHistory = history.compactMap { try? JSONEncoder().encode($0) }
            UserDefaults.standard.set(encodedHistory, forKey: "History")
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRecord = history[indexPath.row]
        
        // Передача данных через делегат или замыкание
        didSelectHistoryRecord?(selectedRecord)
        
        // Вернуться к предыдущему экрану
        navigationController?.popViewController(animated: true)
    }

}

import Foundation

struct TranslationRecord: Codable {
    let sourceText: String       // Исходный текст
    let translatedText: String   // Переведённый текст
    let sourceLanguage: String   // Код исходного языка (например, "ru")
    let targetLanguage: String   // Код языка перевода (например, "en")
}
