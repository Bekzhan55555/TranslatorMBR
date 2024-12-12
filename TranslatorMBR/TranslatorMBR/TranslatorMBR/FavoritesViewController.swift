import UIKit

class FavoritesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    var favorites: [TranslationRecord] = []
    var languages: [String: String] = [:] // Словарь языков
    var didSelectFavRecord: ((TranslationRecord) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Регистрация стандартной ячейки
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FavoritesCell")
        tableView.dataSource = self
        tableView.delegate = self
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favorites.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FavoritesCell", for: indexPath)
        let record = favorites[indexPath.row]
        
        // Приведение языковых кодов к стандартному виду
        let sourceLangCode = record.sourceLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetLangCode = record.targetLanguage.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Получение названия языков
        let sourceLangName = languages[sourceLangCode] ?? "Unknown"
        let targetLangName = languages[targetLangCode] ?? "Unknown"
        
        // Формат текста: "Мир(рус) -> World(eng)"
        cell.textLabel?.text = "\(record.sourceText) (\(sourceLangName)) -> \(record.translatedText) (\(targetLangName))"
        // Настройка шрифта и переносов
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.numberOfLines = 0
        return cell
    }

    // Удаление элемента из избранного
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            favorites.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            // Обновление сохраненных данных
            UserDefaults.standard.set(favorites.map { try? JSONEncoder().encode($0) }, forKey: "Favorites")
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRecord = favorites[indexPath.row]
        
        // Передача данных через делегат или замыкание
        didSelectFavRecord?(selectedRecord)
        
        // Вернуться к предыдущему экрану
        navigationController?.popViewController(animated: true)
    }

}
