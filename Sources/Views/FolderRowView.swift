import SwiftUI

struct FolderRowView: View {
    let folder: Asset
    @Environment(AssetStore.self) private var store
    @State private var isExpanded = false
    @State private var isHovering = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if let children = folder.children, !children.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))], spacing: 12) {
                    ForEach(children) { asset in
                        AssetItemView(asset: asset)
                            .onDrag {
                                NSItemProvider(object: (asset.textContent ?? "Asset") as NSString)
                            }
                    }
                }
                .padding(.vertical, 8)
                .padding(.leading, 16)
            } else {
                Text("Empty Folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading, 16)
            }
        } label: {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.blue)
                Text(folder.name ?? "Untitled Folder")
                    .font(.headline)
                Spacer()
                
                if isHovering {
                    Button(action: { store.delete(folder) }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
        }
        .padding(.horizontal)
    }
}
