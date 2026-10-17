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

extension UILabel {

    /// Yuvarlak köşeli arka planı MASKESİZ verir.
    ///
    /// `UILabel` `backgroundColor`'ı kendi içeriğine çizer; köşeyi yuvarlatmak için
    /// `clipsToBounds` (maske) gerekir ve içerikli bir katmanı maskelemek GPU'da ekstra bir
    /// "offscreen" çizim geçişi demektir (Instruments → Color Off-screen Rendered: sarı).
    /// Rengi katmanın kendi arka planına verince köşe maske olmadan yuvarlanır.
    /// Not: `CGColor` dinamik değil; açık/koyu mod değişince tekrar çağrılmalı.
    func setRoundedBackground(_ color: UIColor, cornerRadius: CGFloat) {
        backgroundColor = .clear
        layer.backgroundColor = color.resolvedColor(with: traitCollection).cgColor
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
    }
}
