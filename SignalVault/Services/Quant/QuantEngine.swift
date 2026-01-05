import Foundation
import Darwin

actor QuantEngine {
    
    // Standard Normal Cumulative Distribution Function
    // Using error function approximation or Darwin.erf
    private func normalCDF(_ x: Double) -> Double {
        return 0.5 * (1.0 + erf(x / sqrt(2.0)))
    }
    
    // Probability Density Function
    private func normalPDF(_ x: Double) -> Double {
        return (1.0 / sqrt(2.0 * .pi)) * exp(-0.5 * x * x)
    }
    
    // Black-Scholes Formula
    // r = risk free rate (e.g. 0.04 for 4%)
    // T = time to maturity in years
    // sigma = implied volatility (e.g. 0.20 for 20%)
    func calculatePriceAndGreeks(stockPrice S: Double, strikePrice K: Double, timeToMaturity T: Double, riskFreeRate r: Double, volatility sigma: Double, type: OptionType) -> (price: Double, greeks: Greeks) {
        
        let d1 = (log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrt(T))
        let d2 = d1 - sigma * sqrt(T)
        
        let nd1 = normalCDF(d1)
//        let nd2 = normalCDF(d2)
        let nPd1 = normalPDF(d1) // N'(d1)
        
        var price: Double = 0.0
        var delta: Double = 0.0
        var theta: Double = 0.0
        
        // Common Greeks
        // Gamma = N'(d1) / (S * sigma * sqrt(T))
        let gamma = nPd1 / (S * sigma * sqrt(T))
        
        // Vega = S * sqrt(T) * N'(d1)
        // Usually expressed as change per 1% change in vol / 100
        let vega = (S * sqrt(T) * nPd1) / 100.0 
        
        // Rho (Sensitivity to interest rate)
        // Call Rho = K * T * e^(-rT) * N(d2)
        // Put Rho = -K * T * e^(-rT) * N(-d2)
        let rho: Double // Implementing simple placeholder for now or full calc if needed. 
        // Let's stick to core Delta/Theta/Vega/Gamma
        let eMinRt = exp(-r * T)
        
        if type == .call {
            let nd2 = normalCDF(d2)
            price = S * nd1 - K * eMinRt * nd2
            delta = nd1
            
            // Theta Call
            // -(S * sigma * N'(d1)) / (2 * sqrt(T)) - r * K * e^(-rT) * N(d2)
            let term1 = -(S * sigma * nPd1) / (2 * sqrt(T))
            let term2 = -(r * K * eMinRt * nd2)
            theta = (term1 + term2) / 365.0 // Daily Theta
            
            rho = (K * T * eMinRt * nd2) / 100.0
            
        } else {
            // Put
            let nMinD1 = normalCDF(-d1)
            let nMinD2 = normalCDF(-d2)
            
            price = K * eMinRt * nMinD2 - S * nMinD1
            delta = nd1 - 1.0
            
            // Theta Put
            // -(S * sigma * N'(d1)) / (2 * sqrt(T)) + r * K * e^(-rT) * N(-d2)
            let term1 = -(S * sigma * nPd1) / (2 * sqrt(T))
            let term2 = (r * K * eMinRt * nMinD2)
            theta = (term1 + term2) / 365.0
            
            rho = (-K * T * eMinRt * nMinD2) / 100.0
        }
        
        return (price, Greeks(delta: delta, theta: theta, vega: vega, gamma: gamma, rho: rho))
    }
}
