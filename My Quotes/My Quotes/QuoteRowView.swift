//
//  QuoteRowView.swift
//  My Quotes
//
//  Created by Jordan Morgan on 3/28/24.
//

import SwiftUI

struct QuoteRowView: View {
    let quote: Quote
    let onTap: ((Quote) -> ())
    
    var body: some View {
        Button(action: {
            onTap(quote)
        }, label: {
            VStack {
                Text(quote.text)
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .frame(minWidth: 0,
                           maxWidth: .infinity,
                           alignment: .leading)
                    .padding(.vertical, 16)
                Divider()
            }
            .contentShape(RoundedRectangle(cornerRadius: 0))
        })
        .buttonStyle(.plain)
    }
}

#Preview {
    QuoteRowView(quote: .empty) { _ in
        
    }
}
