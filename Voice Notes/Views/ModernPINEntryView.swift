//
//  ModernPINEntryView.swift
//  Voice Notes
//
//  Modern 4-digit PIN entry with instant feedback
//

import SwiftUI

struct ModernPINEntryView: View {
    let mode: PINMode
    let existingPIN: String
    let onSuccess: (String) -> Void  // Pass the PIN back
    let onCancel: () -> Void

    @State private var pinDigits: [String] = ["", "", "", ""]
    @State private var confirmDigits: [String] = ["", "", "", ""]
    @State private var isConfirming = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    @FocusState private var focusedField: Int?

    enum PINMode {
        case create
        case verify
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Title
                VStack(spacing: 8) {
                    Image(systemName: isConfirming ? "checkmark.shield.fill" : "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)

                    Text(titleText)
                        .font(.poppins.title2)
                        .fontWeight(.bold)

                    Text(subtitleText)
                        .font(.poppins.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 16)

                // PIN Display
                HStack(spacing: 20) {
                    ForEach(0..<4, id: \.self) { index in
                        PINDotView(
                            isFilled: currentDigits[index].isEmpty == false,
                            isFocused: focusedField == index,
                            showError: showError
                        )
                    }
                }
                .animation(.spring(response: 0.3), value: currentDigits)
                .animation(.spring(response: 0.3), value: showError)

                // Error message
                if let errorMessage {
                    Text(errorMessage)
                        .font(.poppins.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }

                Spacer()

                // Number pad
                NumberPadView { digit in
                    handleDigitInput(digit)
                } onDelete: {
                    handleDelete()
                }
                .padding(.horizontal)

                // Cancel button
                Button("Cancel") {
                    onCancel()
                }
                .font(.poppins.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onCancel() }
                }
            }
        }
        .onAppear {
            // Auto-focus first field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = 0
            }
        }
    }

    private var currentDigits: [String] {
        isConfirming ? confirmDigits : pinDigits
    }

    private var titleText: String {
        switch mode {
        case .create:
            return isConfirming ? "Confirm PIN" : "Create PIN"
        case .verify:
            return "Enter PIN"
        }
    }

    private var subtitleText: String {
        switch mode {
        case .create:
            return isConfirming ? "Enter your PIN again" : "Choose a 4-digit PIN"
        case .verify:
            return "Enter your 4-digit PIN"
        }
    }

    private func handleDigitInput(_ digit: String) {
        // Clear error on new input
        errorMessage = nil
        showError = false

        // Find first empty slot
        if isConfirming {
            if let emptyIndex = confirmDigits.firstIndex(where: { $0.isEmpty }) {
                confirmDigits[emptyIndex] = digit

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()

                // Check if complete
                if confirmDigits.allSatisfy({ !$0.isEmpty }) {
                    validatePIN()
                }
            }
        } else {
            if let emptyIndex = pinDigits.firstIndex(where: { $0.isEmpty }) {
                pinDigits[emptyIndex] = digit

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()

                // Check if complete
                if pinDigits.allSatisfy({ !$0.isEmpty }) {
                    if mode == .create {
                        // Move to confirmation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isConfirming = true
                        }
                    } else {
                        // Verify immediately
                        validatePIN()
                    }
                }
            }
        }
    }

    private func handleDelete() {
        if isConfirming {
            if let lastFilledIndex = confirmDigits.lastIndex(where: { !$0.isEmpty }) {
                confirmDigits[lastFilledIndex] = ""

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .rigid)
                impact.impactOccurred()
            }
        } else {
            if let lastFilledIndex = pinDigits.lastIndex(where: { !$0.isEmpty }) {
                pinDigits[lastFilledIndex] = ""

                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .rigid)
                impact.impactOccurred()
            }
        }
    }

    private func validatePIN() {
        let enteredPIN = (isConfirming ? confirmDigits : pinDigits).joined()

        switch mode {
        case .create:
            if isConfirming {
                let originalPIN = pinDigits.joined()
                if enteredPIN == originalPIN {
                    // Success - vibrate
                    let success = UINotificationFeedbackGenerator()
                    success.notificationOccurred(.success)
                    onSuccess(originalPIN) // Pass the new PIN
                } else {
                    // Mismatch
                    showErrorState("PINs don't match")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isConfirming = false
                        confirmDigits = ["", "", "", ""]
                        pinDigits = ["", "", "", ""]
                    }
                }
            }
        case .verify:
            if enteredPIN == existingPIN {
                // Success
                let success = UINotificationFeedbackGenerator()
                success.notificationOccurred(.success)
                onSuccess(enteredPIN) // Pass the verified PIN
            } else {
                // Incorrect
                showErrorState("Incorrect PIN")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    pinDigits = ["", "", "", ""]
                }
            }
        }
    }

    private func showErrorState(_ message: String) {
        errorMessage = message
        showError = true

        // Error haptic
        let error = UINotificationFeedbackGenerator()
        error.notificationOccurred(.error)
    }
}

// MARK: - PIN Dot View

struct PINDotView: View {
    let isFilled: Bool
    let isFocused: Bool
    let showError: Bool

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 20, height: 20)
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .scaleEffect(isFilled ? 1.0 : 0.7)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFilled)
    }

    private var fillColor: Color {
        if showError {
            return .red.opacity(0.3)
        } else if isFilled {
            return .blue
        } else {
            return .clear
        }
    }

    private var borderColor: Color {
        if showError {
            return .red
        } else if isFocused {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - Number Pad

struct NumberPadView: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    private let buttons: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "delete"]
    ]

    var body: some View {
        VStack(spacing: 16) {
            ForEach(buttons, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { button in
                        NumberButton(
                            title: button,
                            onTap: {
                                if button == "delete" {
                                    onDelete()
                                } else if !button.isEmpty {
                                    onDigit(button)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

struct NumberButton: View {
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if title == "delete" {
                    Image(systemName: "delete.left.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.primary)
                } else if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(title.isEmpty ? Color.clear : Color(.secondarySystemFill))
            )
        }
        .disabled(title.isEmpty)
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Create PIN") {
    ModernPINEntryView(
        mode: .create,
        existingPIN: "",
        onSuccess: { pin in print("Success: \(pin)") },
        onCancel: { print("Cancel") }
    )
}

#Preview("Verify PIN") {
    ModernPINEntryView(
        mode: .verify,
        existingPIN: "1234",
        onSuccess: { pin in print("Success: \(pin)") },
        onCancel: { print("Cancel") }
    )
}
