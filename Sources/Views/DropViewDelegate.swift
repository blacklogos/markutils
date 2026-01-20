import SwiftUI

struct DropViewDelegate: DropDelegate {
    let destinationItem: Asset
    let assets: [Asset]
    @Binding var draggingItem: Asset?
    let store: AssetStore
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem.id != destinationItem.id else { return }
        
        // Swap creation dates to reorder
        let tempDate = draggingItem.creationDate
        draggingItem.creationDate = destinationItem.creationDate
        destinationItem.creationDate = tempDate
    }
}
