import Foundation
import SwiftUI

@MainActor
class CategorySelectionViewModel: ObservableObject {
    let gameService: GameService
    
    init(gameService: GameService) {
        self.gameService = gameService
    }
    
    var selectedCategories: Set<MusicCategory> {
        gameService.selectedCategories
    }
    
    func toggleCategory(_ category: MusicCategory) async {
        await gameService.toggleCategory(category)
    }
    
    func clearCategories() async {
        await gameService.clearCategories()
    }
    
    var genres: [MusicCategory] {
        MusicCategory.genres
    }
    
    var decades: [MusicCategory] {
        MusicCategory.decades
    }
    
    func isSelected(_ category: MusicCategory) -> Bool {
        selectedCategories.contains(category)
    }
} 