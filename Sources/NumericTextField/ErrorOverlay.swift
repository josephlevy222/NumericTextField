//
//  ErrorOverlay.swift
//
//  Created by Joseph Levy on 4/17/26.
//

import SwiftUI

struct ErrorOverlayModifier: ViewModifier {
	let errorMessage: String?
	@Binding var isFocused: Bool
	@FocusState private var hasFocus: Bool
	var focusBinding: Binding<Bool> { Binding( get: { hasFocus }, set: { hasFocus = $0 } ) }

	func body(content: Content) -> some View {
		content
			.focused($hasFocus)
			.onAppear { isFocused = hasFocus }
			.onChange(of: hasFocus) { isFocused = hasFocus }
//			.border(errorMessage != nil ? Color.red : Color.clear, width: 1.5)
			.overlay(alignment: .topLeading) {
				if let message = errorMessage, hasFocus {
					ErrorBubble(message: message)
						.offset(y: -36)
				}
			}
			.animation(.easeInOut(duration: 0.2), value: isFocused)
	}
}

struct ErrorBubble: View {
	let message: String
	
	var body: some View {
		Text(message)
			.font(.caption)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(Color(.secondarySystemBackground),
						in: RoundedRectangle(cornerRadius: 8))
			.shadow(radius: 3)
			.foregroundColor(.red)
			.clipShape(RoundedRectangle(cornerRadius: 8))
	}
}

// Usage
extension View {
	func errorOverlay(_ message: String?, isFocused: Binding<Bool> = .constant(false)) -> some View {
		modifier(ErrorOverlayModifier(errorMessage: message, isFocused: isFocused))
	}
}

/* At the call site:
	TextField("Email", text: $email)
		.errorOverlay(viewModel.emailError)
*/
