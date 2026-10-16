import UIKit

/// Kenar boşluklu etiket: "pill" (hap) görünümü için. Örn. değişim yüzdesi rozeti.
final class PaddedLabel: UILabel {

    var insets = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6) {
        didSet { invalidateIntrinsicContentSize() }
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}
