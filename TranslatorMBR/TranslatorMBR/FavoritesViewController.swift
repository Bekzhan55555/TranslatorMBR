import UIKit

class FavoritesViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    var favorites: [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
        // Регистрация ячейки
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "FavoritesCell")
    }
}

extension FavoritesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favorites.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FavoritesCell", for: indexPath)
        cell.textLabel?.text = favorites[indexPath.row]
        return cell
    }
}
