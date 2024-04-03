//
//  QuoteView.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/28/24.
//

import SwiftUI

struct QuoteView: View {
    let quote: Quote
    @State private var editingQuoteText: String = ""
    @FocusState private var isFocused: Bool
    @Environment(LocalStore.self) private var store: LocalStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            TextEditor(text: $editingQuoteText)
                .focused($isFocused)
                .font(.system(.title, design: .serif, weight: .bold))
                .padding(.horizontal)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss.callAsFunction()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                        }
                    }
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", systemImage: "trash.circle.fill") {
                            delete()
                        }
                        .tint(Color.red)
                        .opacity(quote.isNewQuote ? 0 : 1)
                    }
                }
        }
        .onAppear {
            editingQuoteText = quote.text
            isFocused.toggle()
        }
    }
    
    private func save() {
        var quoteToSave: Quote = quote
        
        if quoteToSave.isNewQuote {
            quoteToSave = Quote(text: editingQuoteText)
        } else {
            quoteToSave.update(text: editingQuoteText)
        }
        
        store.save(quote: quoteToSave)
        dismiss.callAsFunction()
    }
    
    private func delete() {
        store.remove(quote: quote)
        dismiss.callAsFunction()
    }
}

#Preview {
    QuoteView(quote: .init(text: "Hello World"))
        .environment(LocalStore())
}
