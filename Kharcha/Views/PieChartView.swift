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
    
    @State private var selectedSlice: PieSlice?
    
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
            // Tap outside area to dismiss tooltip
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedSlice = nil
                    }
                }
            
            // Pie slices with small gaps
            ForEach(slices) { slice in
                PieSliceShape(startAngle: slice.startAngle + 1, endAngle: slice.endAngle - 1)
                    .fill(slice.color.gradient)
                    .opacity(selectedSlice == nil || selectedSlice?.category == slice.category ? 1.0 : 0.5)
                    .scaleEffect(selectedSlice?.category == slice.category ? 1.05 : 1.0)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedSlice?.category == slice.category {
                                selectedSlice = nil
                            } else {
                                selectedSlice = slice
                            }
                        }
                    }
            }
            
            // Center hole (donut style)
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 100, height: 100)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selectedSlice = nil
                    }
                }
            
            // Center content - show selected or total
            VStack(spacing: 2) {
                if let selected = selectedSlice {
                    let percentage = grandTotal > 0 ? (selected.value / grandTotal * 100) : 0
                    
                    Text(selected.value.compactFormatted)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(selected.color)
                    
                    Text(selected.category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(selected.color)
                    
                    Text(String(format: "%.1f%%", percentage))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(grandTotal.compactFormatted)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedSlice?.category)
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
