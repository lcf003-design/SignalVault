import SwiftUI

struct LeaderboardView: View {
    @State private var service = MockSocialService()
    @State private var profiles: [PublicTraderProfile] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Global Alpha Leaderboard")
                    .font(.headline)
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal)
            
            if !profiles.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(profiles.prefix(5).enumerated()), id: \.element.id) { index, profile in
                        HStack {
                            // Rank
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            
                            // Tier & Name
                            Text(profile.tier)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.nickname)
                                    .fontWeight(.medium)
                                if profile.isSharingTrades {
                                    Text("Sharing Trades")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            // Stats
                            VStack(alignment: .trailing) {
                                Text(profile.pnlPercent, format: .percent.precision(.fractionLength(1)))
                                    .fontWeight(.bold)
                                    .foregroundStyle(profile.pnlPercent >= 0 ? .green : .red)
                                
                                Text("Win Rate: \(profile.winRate, format: .number.precision(.fractionLength(0)))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(index == 0 ? Color.yellow.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                        
                        if index < 4 {
                            Divider()
                                .padding(.leading, 50)
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .task {
            profiles = await service.fetchLeaderboard()
            isLoading = false
        }
    }
}
