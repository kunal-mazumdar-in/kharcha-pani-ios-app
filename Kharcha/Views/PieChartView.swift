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
        var currentAngle: Double = -90
        
        return categoryTotals.map { item in
            let percentage = grandTotal > 0 ? item.total / grandTotal : 0
            let angle = percentage * 360
            
            let slice = PieSlice(
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
            // Pie slices with small gaps
            ForEach(slices) { slice in
                PieSliceShape(startAngle: slice.startAngle + 1, endAngle: slice.endAngle - 1)
                    .fill(slice.color.gradient)
            }
            
            // Center hole (donut style)
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 100, height: 100)
            
            // Center content
            VStack(spacing: 2) {
                Text(grandTotal.compactFormatted)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
    PieChartView(
        categoryTotals: [
            CategoryTotal(category: "Food", total: 5000, count: 10),
            CategoryTotal(category: "Transport", total: 3000, count: 5),
            CategoryTotal(category: "Shopping", total: 8000, count: 3)
        ],
        grandTotal: 16000
    )
    .frame(width: 200, height: 200)
    .padding()
}
