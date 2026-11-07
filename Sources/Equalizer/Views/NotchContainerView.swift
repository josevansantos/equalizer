import SwiftUI

/// Container reativo que alterna dinamicamente entre NotchCollapsedView e NotchExpandedView.
public struct NotchContainerView: View {
    @ObservedObject var viewModel: NotchViewModel
    var notchHelper: NotchHelper?
    
    public init(viewModel: NotchViewModel, notchHelper: NotchHelper? = nil) {
        self.viewModel = viewModel
        self.notchHelper = notchHelper
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            if viewModel.state == .collapsed {
                NotchCollapsedView(viewModel: viewModel) {
                    viewModel.toggleExpand()
                    notchHelper?.updatePosition(animated: true)
                }
                .transition(.opacity)
            } else {
                NotchExpandedView(viewModel: viewModel) {
                    viewModel.collapse()
                    notchHelper?.updatePosition(animated: true)
                }
                .transition(.opacity)
            }
        }
        .frame(width: viewModel.targetWidth, height: viewModel.targetHeight, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.78, blendDuration: 0), value: viewModel.state)
    }
}
