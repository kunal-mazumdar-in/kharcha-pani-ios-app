import SwiftUI

struct PieSlice: Identifiable {
    let id = UUID()
    let category: String
    let value: Double
    let color: Color
    var startAngle: Double = 0
    var endAngle: Double = 0
}

struct PieChartView: View {
    let categoryTotals: [CategoryTotal]
    let grandTotal: Double
    
    private var slices: [PieSlice] {
        var currentAngle: Double = -90 // Start from top
        
        return categoryTotals.map { item in
            let percentage = grandTotal > 0 ? item.total / grandTotal : 0
            let angle = percentage * 360
            
            var slice = PieSlice(
                category: item.category,
                value: item.total,
                color: AppTheme.colorForCategory(item.category),
                startAngle: currentAngle,
                endAngle: currentAngle + angle
            )
            
            currentAngle += angle
            return slice
        }
    }
    
    var body: some View {
        ZStack {
            // Pie slices
            ForEach(slices) { slice in
                PieSliceShape(startAngle: slice.startAngle, endAngle: slice.endAngle)
                    .fill(slice.color)
            }
            
            // Center hole (donut style)
            Circle()
                .fill(AppTheme.background)
                .frame(width: 100, height: 100)
            
            // Center text
            VStack(spacing: 2) {
                Text("₹")
                    .font(.caption)
                    .foregroundColor(AppTheme.textMuted)
                Text(formatAmount(grandTotal))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount >= 100000 {
            return String(format: "%.1fL", amount / 100000)
        } else if amount >= 1000 {
            return String(format: "%.1fK", amount / 1000)
        } else {
            return String(format: "%.0f", amount)
        }
    }
}

struct PieSliceShape: Shape {
    let startAngle: Double
    let endAngle: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        PieChartView(
            categoryTotals: [
                CategoryTotal(category: "Food", total: 5000, count: 10),
                CategoryTotal(category: "Transport", total: 3000, count: 5),
                CategoryTotal(category: "Shopping", total: 8000, count: 3)
            ],
            grandTotal: 16000
        )
        .frame(width: 200, height: 200)
    }
}

