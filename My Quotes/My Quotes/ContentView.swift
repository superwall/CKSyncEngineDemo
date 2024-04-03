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
            .animation(.easeInOut, value: store.quotes)
            emptyView
            Spacer()
        }
        .padding()
        .toolbar {
            #if os(macOS)
            let placement: ToolbarItemPlacement = .automatic
            #else
            let placement: ToolbarItemPlacement = .bottomBar
            #endif
            ToolbarItemGroup(placement: placement) {
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
