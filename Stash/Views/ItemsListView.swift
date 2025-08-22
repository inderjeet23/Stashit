import SwiftUI
import CoreData

struct ItemsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var dataController: DataController
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StashItem.createdAt, ascending: false)],
        animation: .default)
    private var items: FetchedResults<StashItem>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items, id: \.id) { item in
                    StashItemRow(item: item)
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("All Items")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)
            dataController.save()
        }
    }
}

#Preview {
    ItemsListView()
        .environmentObject(DataController())
}