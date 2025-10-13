//
//  View+Extensions.swift
//  BlueBoxy
//
//  Common SwiftUI view extensions
//

import SwiftUI

extension View {
    /// Applies a conditional modifier
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Applies a conditional modifier with else clause
    @ViewBuilder
    func `if`<T: View, U: View>(
        _ condition: Bool,
        then: (Self) -> T,
        else: (Self) -> U
    ) -> some View {
        if condition {
            then(self)
        } else {
            `else`(self)
        }
    }
    
    /// Hide/show view based on condition
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.hidden()
        } else {
            self
        }
    }
}