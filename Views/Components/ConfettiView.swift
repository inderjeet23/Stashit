import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.midX, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)

        emitter.emitterCells = [
            makeCell(emoji: "🎉"),
            makeCell(emoji: "✨"),
            makeCell(emoji: "✅")
        ]

        view.layer.addSublayer(emitter)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            emitter.birthRate = 0
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func makeCell(emoji: String) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.birthRate = 6
        cell.lifetime = 4.0
        cell.velocity = 160
        cell.velocityRange = 60
        cell.emissionLongitude = .pi
        cell.emissionRange = .pi / 6
        cell.spin = 3.5
        cell.spinRange = 4
        cell.scale = 0.6
        cell.scaleRange = 0.3
        cell.contents = image(from: emoji).cgImage
        return cell
    }

    private func image(from text: String) -> UIImage {
        let size = CGSize(width: 24, height: 24)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let ns = text as NSString
            ns.draw(at: CGPoint(x: 0, y: 0), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
        }
    }
}

