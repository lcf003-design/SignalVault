import SwiftUI

struct DisclaimerView: View {
    @Binding var hasAccepted: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                
                Text("Sandbox Environment")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                VStack(spacing: 16) {
                    Text("SignalVault is a sandbox simulator designed for educational and entertainment purposes only.")
                        .multilineTextAlignment(.center)
                    
                    Text(" All trades are virtual.")
                        .fontWeight(.bold)
                    
                    Text("Not financial advice.")
                        .font(.headline)
                        .foregroundStyle(.red)
                }
                .font(.body)
                .foregroundStyle(.gray)
                .padding(.horizontal, 40)
                
                Spacer()
                    .frame(height: 20)
                
                Button(action: {
                    withAnimation {
                        hasAccepted = true
                    }
                }) {
                    Text("I Understand & Agree")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 60)
        }
    }
}

#Preview {
    DisclaimerView(hasAccepted: .constant(false))
}
