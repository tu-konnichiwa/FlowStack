import SwiftUI

public extension Binding {
    @MainActor
    func flowDialogFilter<Dialog>(
        _ isIncluded: @escaping @MainActor (Dialog) -> Bool
    ) -> Binding<Dialog?> where Value == Dialog? {
        Binding<Dialog?>(
            get: {
                guard let dialog = wrappedValue, isIncluded(dialog) else {
                    return nil
                }

                return dialog
            },
            set: { newValue in
                if let newValue {
                    wrappedValue = newValue
                } else if let dialog = wrappedValue, isIncluded(dialog) {
                    wrappedValue = nil
                }
            }
        )
    }
}
