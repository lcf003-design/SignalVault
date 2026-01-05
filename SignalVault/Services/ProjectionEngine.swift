import Foundation

actor ProjectionEngine {
    
    // Config
    private let lookbackPeriod = 30
    private let forecastHorizon = 30
    
    func calculateProjection(recentPrices: [Double]) -> ProjectionResult? {
        guard recentPrices.count >= lookbackPeriod else { return nil }
        
        let data = Array(recentPrices.suffix(lookbackPeriod))
        let n = Double(data.count)
        
        // 1. OLS Regression
        // x = 0 to n-1
        // y = price
        
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX2 = 0.0
        
        for (i, y) in data.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += (x * y)
            sumX2 += (x * x)
        }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // 2. R-Squared & Standard Deviation (Volatility)
        var ssTot = 0.0 // Total Sum of Squares
        var ssRes = 0.0 // Residual Sum of Squares
        let meanY = sumY / n
        
        var residuals: [Double] = []
        
        for (i, y) in data.enumerated() {
            let x = Double(i)
            let predictedY = slope * x + intercept
            let res = y - predictedY
            residuals.append(res)
            
            ssRes += (res * res)
            ssTot += (y - meanY) * (y - meanY)
        }
        
        let rSquared = 1.0 - (ssRes / ssTot)
        
        // Calculate Standard Deviation of Residuals (Noise Level)
        // Using sample standard deviation formula
        let stdDev = sqrt(ssRes / (n - 2)) // n-2 degrees of freedom for regression
        
        // 3. Generate Future Cone
        var points: [ProjectionPoint] = []
        
        // Current index is n-1. Future starts at n.
        let startIndex = Int(n)
        
        for i in 1...forecastHorizon {
            let futureX = Double(startIndex + i - 1) // Continue the trend
            let projectedPrice = slope * futureX + intercept
            
            // Cone widening logic: Uncertainty grows with sqrt of time
            // We use the calculated stdDev as the base unit.
            // At step 1, width is 1 * SD. At step 30, width is sqrt(30) * SD?
            // Usually it's SD * sqrt(t).
            
            let timeFactor = sqrt(Double(i))
            let coneWidth1SD = stdDev * timeFactor
            let coneWidth2SD = stdDev * timeFactor * 2.0
            
            let point = ProjectionPoint(
                indexOffset: i,
                price: projectedPrice,
                upper1SD: projectedPrice + coneWidth1SD,
                lower1SD: projectedPrice - coneWidth1SD,
                upper2SD: projectedPrice + coneWidth2SD,
                lower2SD: projectedPrice - coneWidth2SD
            )
            points.append(point)
        }
        
        // Truth Filter: R² > 0.3 for minimal trend reliability?
        // Prompt implies gray cone if low confidence.
        let isReliable = rSquared > 0.3
        
        // Calculate Z-Score of the LATEST price (Mean Reversion Trigger)
        // Last point is at x = n - 1
        let lastX = Double(n - 1)
        let lastPredicted = slope * lastX + intercept
        let lastActual = data.last ?? 0.0
        let currentZ = (lastActual - lastPredicted) / (stdDev > 0 ? stdDev : 1.0)
        
        return ProjectionResult(
            points: points,
            rSquared: rSquared,
            slope: slope,
            isReliable: isReliable,
            currentDeviationSigma: currentZ
        )
    }
}
