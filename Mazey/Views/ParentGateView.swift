//
//  ParentGateView.swift
//  Mazey
//

import SwiftUI

/// "Ask a grown-up": something that cannot be undone only goes ahead when a simple sum is
/// answered correctly. `message` says what is about to happen.
struct ParentGateView: View {
    let message: String
    let onPassed: () -> Void
    @State private var gate = ParentGate.make()
    @State private var missed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Ask a grown-up")
                .font(.title2.weight(.semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("What is \(gate.question)?")
                .font(.title.weight(.bold))
                .padding(.top, 4)
            HStack(spacing: 12) {
                ForEach(gate.choices, id: \.self) { choice in
                    Button("\(choice)") { choose(choice) }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .font(.title3.weight(.semibold))
                }
            }
            if missed {
                Text("Not quite. Here is another one.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(24)
        #if os(iOS)
        .presentationDetents([.medium])
        #else
        .frame(width: 420)
        #endif
    }

    private func choose(_ choice: Int) {
        if gate.isCorrect(choice) {
            dismiss()
            onPassed()
        } else {
            missed = true
            gate = ParentGate.make()
        }
    }
}
