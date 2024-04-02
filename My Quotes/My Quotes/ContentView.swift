//
//  ContentView.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/28/24.
//

import SwiftUI

struct ContentView: View {
    @Environment(LocalStore.self) private var store: LocalStore
    @State private var selectedQuote: Quote? = nil
    
    var body: some View {
        VStack {
            Text("Quotes")
                .font(.system(.largeTitle, design: .default, weight: .black))
                .frame(minWidth: 0,
                       maxWidth: .infinity,
                       alignment: .leading)
            ForEach(store.quotes) { quote in
                QuoteRowView(quote: quote) { selection in
                    selectedQuote = selection
                }
            }
            emptyView
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if !store.quotes.isEmpty {
                    Button("Add", systemImage: "plus.circle.fill") {
                        selectedQuote = .empty
                    }
                }
                Spacer()
                Button("Reset", systemImage: "exclamationmark.triangle.fill") {
                    Task {
                        await store.cloudSync.removeAllData()
                        await store.cloudSync.reuploadEverything()
                    }
                }
                .tint(Color.red)
                Spacer()
                Button("Push Latest", systemImage: "icloud.and.arrow.up.fill") {
                    Task {
                        await store.cloudSync.pushLatestChanges()
                    }
                }
                Button("Pull Latest", systemImage: "icloud.and.arrow.down.fill") {
                    Task {
                        await store.cloudSync.pullLatestChanges()
                    }
                }
             }
        }
        .sheet(item: $selectedQuote) { selection in
            QuoteView(quote: selection)
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView(label: {
            Label("No Quotes", systemImage: "quote.closing")
        }, description: {
            Text("Quotes you've added will appear here.")
        }, actions: {
            Button(action: {
                selectedQuote = .empty
            }) {
                Text("Add a Quote")
            }
        })
        .opacity(store.quotes.isEmpty ? 1 : 0)
    }
}

#Preview {
    ContentView()
        .environment(LocalStore())
}
