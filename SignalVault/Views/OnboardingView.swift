import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    
    @State private var currentPage = 0
    private let pages = [
        OnboardingPage(
            imageName: "lock.shield",
            title: "Access the Vault",
            description: "You have been granted a $100,000 Sandbox Account. Trade Stocks, Crypto, and Options without risking real capital."
        ),
        OnboardingPage(
            imageName: "eye.fill",
            title: "Consult the Oracle",
            description: "Our Predictive Engine projects future price ranges (1SD/2SD Cones). Watch for 'Price Stretched' alerts to catch reversals."
        ),
        OnboardingPage(
            imageName: "chart.line.uptrend.xyaxis",
            title: "Beat the Market",
            description: "Check 'The Mirror' dashboard to track your Alpha. Can you outperform the S&P 500? Your performance is your truth."
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }
                
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        VStack(spacing: 20) {
                            Image(systemName: pages[index].imageName)
                                .font(.system(size: 80))
                                .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .padding(.bottom, 40)
                            
                            Text(pages[index].title)
                                .font(.largeTitle.bold())
                                .foregroundColor(.white)
                            
                            Text(pages[index].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(height: 400)
                
                Spacer()
                
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Next" : "Enter the Command Center")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            isPresented = false
        }
    }
}

struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}
