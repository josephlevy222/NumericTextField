//
//  ErrorOverlay.swift
//
//  Created by Joseph Levy on 4/17/26.
//

import SwiftUI
import SwiftUIIntrospect

struct ErrorOverlayModifier: ViewModifier {
	let errorMessage: String?
	@State private var bubbleSize: CGSize = .zero
	@State private var fieldFrame: CGRect = .zero
	@FocusState var hasFocus: Bool
	func body(content: Content) -> some View {
		content
			.focused($hasFocus)
			.border(errorMessage != nil ? Color.red : Color.clear, width: 1.5)
			.background(
				GeometryReader { geo in
					Color.clear
						.onAppear { fieldFrame = geo.frame(in: .global) }
						.onChange(of: geo.frame(in: .global)) { fieldFrame = geo.frame(in: .global) }
				}
			)
			.overlay(alignment: .topLeading) {
				if let message = errorMessage, hasFocus {
					let screenWidth = UIScreen.main.bounds.width
					let showBelow = fieldFrame.minY < (bubbleSize.height + 6)
					let clampedX = min( max(fieldFrame.minX, 8), screenWidth - bubbleSize.width - 8) - fieldFrame.minX
					let yOffset = showBelow ? fieldFrame.height + 6 : -(bubbleSize.height + 6)
					
					ErrorBubble(message: message, renderedSize: $bubbleSize)
						.offset(x: clampedX, y: yOffset)
				}
			}
	}
}

struct ErrorBubble: View {
	let message: String
	@Binding var renderedSize: CGSize      // capture both dimensions
	var body: some View {
		Text(message)
			.font(.caption)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
			.shadow(radius: 3)
			.foregroundColor(.red)
			.fixedSize()
			.background(
				GeometryReader { geo in
					Color.clear
						.onAppear { renderedSize = geo.size }
						.onChange(of: geo.size) { renderedSize = geo.size }
				}
			)
	}
}

// Usage
extension View {
	func errorOverlay(_ message: String?) -> some View {
		modifier(ErrorOverlayModifier(errorMessage: message))
	}
}

/* At the call site:
	TextField("Email", text: $email)
		.errorOverlay(viewModel.emailError)
*/
