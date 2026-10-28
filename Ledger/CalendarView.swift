import SwiftUI

struct CalendarView: View {

    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var navigationMode = "month"
    @State private var showingDailyActivity = false

    private let calendar = Calendar.current

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 10),
        count: 7
    )

    // MARK: - Month Title

    private var monthTitle: String {
        displayedMonth.formatted(
            .dateTime.month(.wide).year()
        )
    }

    // MARK: - Weekday Names

    private var weekdayNames: [String] {

        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1

        return Array(symbols[start...]) +
               Array(symbols[..<start])
    }

    // MARK: - Calendar Days

    private var monthDays: [Date?] {

        guard let interval = calendar.dateInterval(
            of: .month,
            for: displayedMonth
        ) else {
            return []
        }

        let firstDay = interval.start

        let weekday = calendar.component(
            .weekday,
            from: firstDay
        )

        let offset = (
            weekday - calendar.firstWeekday + 7
        ) % 7

        guard let range = calendar.range(
            of: .day,
            in: .month,
            for: displayedMonth
        ) else {
            return []
        }

        let blankDays = Array<Date?>(
            repeating: nil,
            count: offset
        )

        let days: [Date?] = range.compactMap { day in
            calendar.date(
                byAdding: .day,
                value: day - 1,
                to: firstDay
            )
        }.map { Optional($0) }

        return blankDays + days
    }

    // MARK: - Body

    var body: some View {

        VStack(spacing: 24) {

            // Month Navigation

            
            
            HStack(spacing: 16) {

                Button {
                    changeDate(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }

                Spacer()

                HStack(spacing: 8) {

                    Button {
                        navigationMode = "month"
                    } label: {
                        Text(
                            displayedMonth.formatted(
                                .dateTime.month(.wide)
                            )
                        )
                        .font(.title2.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            navigationMode == "month"
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                    }

                    Button {
                        navigationMode = "year"
                    } label: {
                        Text(
                            displayedMonth.formatted(
                                .dateTime.year()
                            )
                        )
                        .font(.title2.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            navigationMode == "year"
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                    }
                }

                Spacer()

                Button {
                    changeDate(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }
            .buttonStyle(.plain)


            // Weekday Headers

            LazyVGrid(columns: columns, spacing: 10) {

                ForEach(weekdayNames, id: \.self) { day in

                    Text(day)
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar Grid

            LazyVGrid(columns: columns, spacing: 10) {

                ForEach(
                    Array(monthDays.enumerated()),
                    id: \.offset
                ) { _, date in

                    if let date = date {

                        dayCell(date)

                    } else {

                        Color.clear
                            .frame(height: 75)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(30)
        .frame(minWidth: 850, minHeight: 650)
        .sheet(isPresented: $showingDailyActivity) {
            DailyFinancialActivityView(date: selectedDate)
        }
        .sheet(isPresented: $showingDailyActivity) {
            DailyFinancialActivityView(date: selectedDate)
        }
    }

    // MARK: - Change Month

    private func changeMonth(_ amount: Int) {

        guard let newMonth = calendar.date(
            byAdding: .month,
            value: amount,
            to: displayedMonth
        ) else {
            return
        }

        displayedMonth = newMonth
    }
    

    // MARK: - Day Cell

    private func dayCell(_ date: Date) -> some View {

        let isSelected = calendar.isDate(
            date,
            inSameDayAs: selectedDate
        )

        let isToday = calendar.isDateInToday(date)

        return Button {

            selectedDate = date

        } label: {

            Text(
                "\(calendar.component(.day, from: date))"
            )
            .font(.headline)
            .foregroundStyle(
                isSelected
                ? Color.white
                : Color.primary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 75)
            .background(
                isSelected
                ? Color.accentColor
                : Color.primary.opacity(0.04)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
            .overlay {

                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isToday
                        ? Color.accentColor
                        : Color.clear,
                        lineWidth: 2
                    )
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                selectedDate = date
                showingDailyActivity = true
            }
        )
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                selectedDate = date
                showingDailyActivity = true
            }
        )
    }
    
    private func changeDate(_ direction: Int) {

        let component: Calendar.Component =
            navigationMode == "year" ? .year : .month

        guard let newDate = calendar.date(
            byAdding: component,
            value: direction,
            to: displayedMonth
        ) else {
            return
        }

        displayedMonth = newDate
    }
}

