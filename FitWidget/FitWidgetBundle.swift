import WidgetKit
import SwiftUI

/// The extension's entry point. A `WidgetBundle` lets the extension vend one or
/// more widgets; Fit ships a single widget for now.
@main
struct FitWidgetBundle: WidgetBundle {
    var body: some Widget {
        FitWidget()
    }
}
