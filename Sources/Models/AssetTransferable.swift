import SwiftUI

struct AssetTransferable: Transferable {
    let asset: Asset
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { transferable in
            if transferable.asset.type == .image, let data = transferable.asset.imageData {
                return data
            }
            return Data()
        }
        
        DataRepresentation(exportedContentType: .plainText) { transferable in
            if transferable.asset.type == .text, let text = transferable.asset.textContent {
                return text.data(using: .utf8) ?? Data()
            }
            return Data()
        }
    }
}
