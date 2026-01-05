import SwiftUI
import Charts
import SwiftData

struct PortfolioSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PortfolioViewModel()
    @Binding var selectedTab: Int // To navigate to Trade tab
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 1. Hero Header
                    VStack(spacing: 8) {
                        Text("TOTAL EQUITY")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .tracking(2)
                        
                        Text(viewModel.totalEquity, format: .currency(code: "USD"))
                            .font(.system(size: 42, weight: .heavy, design: .rounded))
                            .foregroundStyle(Material.thickMaterial)
                            .overlay(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .mask(
                                    Text(viewModel.totalEquity, format: .currency(code: "USD"))
                                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                                )
                            )
                        
                        // Total Open P&L
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.totalPnL >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(viewModel.totalPnL, format: .currency(code: "USD"))
                            Text("Open P&L")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(viewModel.totalPnL >= 0 ? .green : .red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(20)
                    }
                    .padding(.top, 20)
                    
                    // 2. Asset Allocation (Donut Chart)
                    VStack(alignment: .leading) {
                        Text("Allocation")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if viewModel.allocationData.isEmpty {
                            Text("No Assets Found")
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .cornerRadius(16)
                                .padding(.horizontal)
                        } else {
                            Chart(viewModel.allocationData) { segment in
                                SectorMark(
                                    angle: .value("Value", segment.value),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(segment.color)
                            }
                            .frame(height: 250)
                            .padding()
                            
                            // Legend
                            HStack {
                                ForEach(viewModel.allocationData) { segment in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(segment.color)
                                            .frame(width: 8, height: 8)
                                        Text(segment.sector)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // 3. Risk Meter
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Risk Score (VaR)")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.riskScore)/100")
                                .fontWeight(.bold)
                                .foregroundStyle(riskColor)
                        }
                        .padding(.horizontal)
                        
                        // Meter Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(height: 12)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .yellow, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * (Double(viewModel.riskScore) / 100.0), height: 12)
                            }
                        }
                        .frame(height: 12)
                        .padding(.horizontal)
                        
                        Text(riskDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                    
                    // 4. Quick Actions
                    Button(action: { selectedTab = 1 }) { // Jump to Trade
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Go to Command Center")
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .navigationTitle("Home")
                .navigationBarHidden(true)
            }
            .onAppear {
                viewModel.setContext(modelContext)
            }
        }
    }
    
    var riskColor: Color {
        if viewModel.riskScore < 30 { return .green }
        else if viewModel.riskScore < 70 { return .yellow }
        else { return .red }
    }
    
    var riskDescription: String {
        if viewModel.riskScore < 30 { return "Conservative Allocation. Mostly Cash or Blue Chips." }
        else if viewModel.riskScore < 70 { return "Balanced Portfolio. Healthy Mix." }
        else { return "High Volatility detected. Significant Crypto exposure." }
    }
}
