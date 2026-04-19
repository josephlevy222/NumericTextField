//
//  ErrorOverlay.swift
//
//  Created by Joseph Levy on 4/17/26.
//

import SwiftUI

struct FieldGeometry: Equatable {
	var windowBounds: CGRect = UIScreen.main.bounds
	var fieldFrame: CGRect = .zero
}

struct FieldGeometryKey: PreferenceKey {
	static var defaultValue = FieldGeometry()
	static func reduce(value: inout FieldGeometry, nextValue: () -> FieldGeometry) {
		value = nextValue()
	}
}

struct ErrorOverlayModifier: ViewModifier {
	let errorMessage: String?
	@State private var bubbleSize: CGSize = .zero
	@State private var geometry: FieldGeometry = .init()
	@FocusState var hasFocus: Bool
	
	private func updateGeometry(_ geo: GeometryProxy) {
		let fieldFrame = geo.frame(in: .global)
		let windowBounds = UIApplication.shared
			.connectedScenes
			.compactMap { $0 as? UIWindowScene }
			.flatMap { $0.windows }
			.first { $0.isKeyWindow }?.bounds
		?? UIScreen.main.bounds  // fallback for older iOS
		
		geometry = FieldGeometry(windowBounds: windowBounds, fieldFrame: fieldFrame)
	}

	func body(content: Content) -> some View {
		content
			.focused($hasFocus)
			.onPreferenceChange(FieldGeometryKey.self) { geometry = $0 }
			.background(
				GeometryReader { geo in
					Color.clear
						.onAppear { updateGeometry(geo) }
						.onChange(of: geo.frame(in: .global)) { //_ in
							updateGeometry(geo)
						}
				}
			)
			.border(errorMessage != nil ? Color.red : Color.clear, width: 1.5)

			.overlay(alignment: .topLeading) {
				if let message = errorMessage, hasFocus {
					let showBelow = geometry.fieldFrame.minY < (bubbleSize.height + 6)
					let clampedX = min(
						max(geometry.fieldFrame.minX, 8),
						geometry.windowBounds.width - bubbleSize.width - 8
					) - geometry.fieldFrame.minX
					let yOffset = showBelow
					? geometry.fieldFrame.height + 6
					: -(bubbleSize.height + 6)
					
					ErrorBubble(message: message, renderedSize: $bubbleSize)
						.offset(x: clampedX, y: yOffset)
				}
			}
			.animation(.easeInOut(duration: 0.2), value: hasFocus)
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
