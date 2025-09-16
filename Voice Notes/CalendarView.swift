import SwiftUI

struct LiquidCalendarView: View {
    @Binding var selectedDate: Date?
    @State private var currentMonth = Date()
    @State private var isExpanded = false
    @State private var animationOffset: CGFloat = 0
    
    let recordings: [Recording]
    let startExpanded: Bool
    
    init(selectedDate: Binding<Date?>, recordings: [Recording], startExpanded: Bool = false) {
        self._selectedDate = selectedDate
        self.recordings = recordings
        self.startExpanded = startExpanded
    }
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with liquid morphing effect
            headerView
            
            // Calendar grid with liquid animations
            if isExpanded {
                calendarGrid
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: isExpanded ? 28 : 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: isExpanded ? 28 : 20, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: isExpanded ? 20 : 10, y: isExpanded ? 10 : 5)
        )
        .scaleEffect(isExpanded ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.6, extraBounce: 0.1), value: isExpanded)
        .onAppear {
            if startExpanded {
                isExpanded = true
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // Liquid calendar icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.blue.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: isExpanded ? "calendar.badge.checkmark" : "calendar")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .scaleEffect(isExpanded ? 1.1 : 1.0)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: isExpanded ? 8 : 4, y: 2)
            }
            .animation(.smooth(duration: 0.4), value: isExpanded)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dateFormatter.string(from: currentMonth))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                
                if let selectedDate = selectedDate {
                    Text(formatSelectedDate(selectedDate))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .push(from: .leading)))
                } else {
                    Text("Select a date")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Liquid expand/collapse button
            Button(action: { 
                withAnimation(.smooth(duration: 0.6, extraBounce: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isExpanded ? .blue : .secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .scaleEffect(isExpanded ? 1.1 : 1.0)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.smooth(duration: 0.6, extraBounce: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var calendarGrid: some View {
        VStack(spacing: 12) {
            // Month navigation
            monthNavigationView
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                // Day headers
                ForEach(dayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(height: 32)
                }
                
                // Date cells
                ForEach(calendarDays, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        selectedDate: selectedDate,
                        currentMonth: currentMonth,
                        hasRecordings: hasRecordings(for: date),
                        recordingCount: recordingCount(for: date)
                    ) { date in
                        withAnimation(.smooth(duration: 0.4, extraBounce: 0.3)) {
                            if calendar.isDate(date, inSameDayAs: selectedDate ?? Date.distantPast) {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }
    
    private var monthNavigationView: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(dateFormatter.string(from: currentMonth))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
    
    private var dayHeaders: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
    
    private var calendarDays: [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: currentMonth)?.start ?? currentMonth
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date] = []
        for i in 0..<42 { // 6 weeks
            if let date = calendar.date(byAdding: .day, value: i, to: startOfCalendar) {
                days.append(date)
            }
        }
        return days
    }
    
    private func hasRecordings(for date: Date) -> Bool {
        recordings.contains { recording in
            calendar.isDate(recording.date, inSameDayAs: date)
        }
    }
    
    private func recordingCount(for date: Date) -> Int {
        recordings.filter { recording in
            calendar.isDate(recording.date, inSameDayAs: date)
        }.count
    }
    
    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func previousMonth() {
        withAnimation(.smooth(duration: 0.5)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.smooth(duration: 0.5)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let selectedDate: Date?
    let currentMonth: Date
    let hasRecordings: Bool
    let recordingCount: Int
    let onTap: (Date) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            // Liquid background
            RoundedRectangle(cornerRadius: isSelected ? 16 : 12, style: .continuous)
                .fill(backgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: isSelected ? 16 : 12, style: .continuous)
                        .stroke(strokeColor, lineWidth: isSelected ? 2 : 1)
                )
                .scaleEffect(isSelected ? 1.1 : (hasRecordings ? 1.02 : 1.0))
                .shadow(
                    color: isSelected ? .blue.opacity(0.3) : .clear,
                    radius: isSelected ? 8 : 0,
                    y: isSelected ? 4 : 0
                )
            
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(textColor)
                
                if hasRecordings && recordingCount > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<min(recordingCount, 3), id: \.self) { _ in
                            Circle()
                                .fill(.blue.gradient)
                                .frame(width: 4, height: 4)
                        }
                        if recordingCount > 3 {
                            Text("+")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(date)
        }
        .animation(.smooth(duration: 0.4, extraBounce: 0.2), value: isSelected)
        .animation(.smooth(duration: 0.3), value: hasRecordings)
    }
    
    private var isSelected: Bool {
        guard let selectedDate = selectedDate else { return false }
        return calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isCurrentMonth: Bool {
        calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    private var isToday: Bool {
        calendar.isDate(date, inSameDayAs: Date())
    }
    
    private var backgroundGradient: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(.blue.gradient)
        } else if hasRecordings {
            return AnyShapeStyle(.blue.opacity(0.1).gradient)
        } else if isToday {
            return AnyShapeStyle(.gray.opacity(0.2).gradient)
        } else {
            return AnyShapeStyle(.clear)
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return .blue.opacity(0.8)
        } else if hasRecordings {
            return .blue.opacity(0.3)
        } else if isToday {
            return .gray.opacity(0.5)
        } else {
            return .clear
        }
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isCurrentMonth {
            return .secondary
        } else if isToday {
            return .primary
        } else {
            return .primary
        }
    }
}

#Preview {
    LiquidCalendarView(
        selectedDate: .constant(Date()),
        recordings: [
            Recording(fileName: "test1.m4a", date: Date(), title: "Test 1"),
            Recording(fileName: "test2.m4a", date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(), title: "Test 2")
        ],
        startExpanded: true
    )
    .padding()
}
