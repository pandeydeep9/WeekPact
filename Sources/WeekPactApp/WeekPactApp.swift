import Foundation
import SwiftUI
import WeekPactCore

@main
struct WeekPactApp: App {
    @StateObject private var trial = TrialController()
    @StateObject private var usage = UsageController()
    @StateObject private var filter = FilterSetupController()
    @StateObject private var limits = LimitController()

    var body: some Scene {
        WindowGroup("WeekPact") {
            WeekPactView(trial: trial, usage: usage, filter: filter, limits: limits)
                .frame(minWidth: 700, minHeight: 530)
        }
    }
}

struct WeekPactView: View {
    @ObservedObject var trial: TrialController
    @ObservedObject var usage: UsageController
    @ObservedObject var filter: FilterSetupController
    @ObservedObject var limits: LimitController

    @State private var page: Page = .today
    @State private var command = ""
    @State private var selected = Set<LockedService>()
    @State private var minutes = 30
    @State private var endDay: Weekday = .monday
    @State private var confirmLock = false

    private enum Page: String, CaseIterable, Identifiable {
        case today = "Today", lock = "Lock", report = "Report"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("WeekPact").font(.title.bold())
                Spacer()
                Picker("Screen", selection: $page) {
                    ForEach(Page.allCases) { screen in Text(screen.rawValue).tag(screen) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
            }
            HStack {
                TextField("Type “generate report”", text: $command)
                    .onSubmit(runCommand)
                Button("Go", action: runCommand)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch page {
                    case .today: todayView
                    case .lock: lockView
                    case .report: reportView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: 860)
        .frame(maxWidth: .infinity)
        .onAppear { filter.refreshStatus(); limits.refresh() }
        .confirmationDialog("Lock selected services until the chosen midnight?",
                            isPresented: $confirmLock, titleVisibility: .visible) {
            Button("Lock until \(endDate.formatted(date: .abbreviated, time: .shortened))") {
                if limits.commit(services: selected, minutes: minutes, endDay: endDay,
                                 filterEnabled: filter.isEnabled, usage: usage) {
                    if selected.contains(.youtube) { trial.end() }
                    selected = []
                    page = .today
                }
            }
        } message: {
            Text("Daily minutes refill at midnight. The lock cannot be loosened in WeekPact before its end time.")
        }
    }

    private func runCommand() {
        let input = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if input.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".!?")) == "generate report" {
            usage.generateReport()
            page = .report
        }
        command = ""
    }

    private var endDate: Date {
        LimitClock.nextMidnight(on: endDay, after: .now, timeZoneID: TimeZone.current.identifier)
    }

    private var todayView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Today").font(.title2.bold())
                Spacer()
                Button(usage.isTracking ? "Pause tracking" : "Resume tracking") {
                    usage.setTracking(!usage.isTracking)
                }
                Button("New lock") { page = .lock }
                    .buttonStyle(.borderedProminent)
            }
            GroupBox("Active locks") {
                VStack(alignment: .leading, spacing: 10) {
                    if limits.book.active(at: .now).isEmpty {
                        Text("No services locked yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(limits.book.active(at: .now)) { limit in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(limit.service.title).font(.headline)
                                    Text("\(limit.dailySeconds / 60) min/day · ends \(limit.endsAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                                    Text(countdown(until: limit.endsAt, at: timeline.date))
                                        .font(.callout).monospacedDigit()
                                }
                            }
                        }
                    }
                    Text(filter.status).font(.caption).foregroundStyle(filter.isEnabled ? Color.secondary : Color.orange)
                }.padding(8)
            }
            GroupBox("Website time today") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(duration(usage.today.totalSeconds)).font(.largeTitle.bold()).monospacedDigit()
                    if usage.today.sites.isEmpty {
                        Text("No foreground website time recorded today.").foregroundStyle(.secondary)
                    } else {
                        ForEach(usage.today.sites.prefix(4)) { row in usageRow(row) }
                    }
                    HStack {
                        Button("Generate 7-day report") { usage.generateReport(); page = .report }
                        Spacer()
                        Text("Safari + Chrome · local only").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(8)
            }
            Text(usage.status).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup("Old five-minute YouTube browser trial") {
                VStack(alignment: .leading, spacing: 8) {
                    if trial.isRunning {
                        Text("\(Int(trial.remainingSeconds.rounded(.up))) seconds left today")
                        Button("End browser trial") { trial.end() }
                    } else {
                        Button("Start browser trial") { trial.start() }
                    }
                    Text("This optional trial is bypassable. Ending it does not change an active lock.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
        }
    }

    private var lockView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set a limit").font(.title2.bold())
            Text("Starts now. Each selected service gets its own daily allowance; the rule lasts until the chosen midnight.")
                .foregroundStyle(.secondary)
            GroupBox("1 · Services") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                    ForEach(LockedService.allCases) { service in
                        Toggle(service.title, isOn: Binding(
                            get: { selected.contains(service) },
                            set: { enabled in
                                if enabled { selected.insert(service) } else { selected.remove(service) }
                            }
                        ))
                        .disabled(limits.book.active(at: .now).contains { $0.service == service })
                    }
                }.padding(8)
            }
            HStack(spacing: 20) {
                Picker("2 · Daily limit", selection: $minutes) {
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("3 hours").tag(180)
                }
                Picker("3 · End day", selection: $endDay) {
                    ForEach(Weekday.ordered) { day in Text(day.fullName).tag(day) }
                }
            }
            .pickerStyle(.menu)
            Text("Starts now → \(endDate.formatted(date: .abbreviated, time: .shortened)) (\(TimeZone.current.identifier)). Daily minutes refill at local midnight; the rule does not.")
                .font(.callout)
            Button("Lock selected services") { confirmLock = true }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty || !filter.isEnabled)
            Text(limits.status).font(.callout).foregroundStyle(.secondary)
            GroupBox("macOS filter setup") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(filter.status).font(.callout)
                    HStack {
                        Button("Enable filter") { filter.install() }
                        Button("Refresh status") { filter.refreshStatus() }
                        Button("Test example.com · 60s") { filter.startShortTest() }
                            .disabled(!filter.isEnabled)
                    }
                    Text("Requires the signed Xcode app and macOS approval. Other browsers and native clients are blocked for selected sites while a lock is active because their viewing time is not measured.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }
            Text("An administrator can still remove or disable software. Coverage and restart behavior need testing on your Mac before relying on this lock.")
                .font(.caption).foregroundStyle(.orange)
        }
    }

    private var reportView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Usage report").font(.title2.bold())
                Spacer()
                Button("Generate report") { usage.generateReport() }
                    .buttonStyle(.borderedProminent)
            }
            if let report = usage.generatedReport {
                Text("Last 7 local days · generated \(report.end.formatted(date: .abbreviated, time: .shortened))")
                    .foregroundStyle(.secondary)
                Text(duration(report.totalSeconds)).font(.largeTitle.bold())
                if report.sites.isEmpty {
                    Text("No sites recorded in this period.")
                } else {
                    ForEach(report.sites) { row in usageRow(row) }
                }
                Text("Saved locally in Application Support/WeekPact/usage.json. Page paths, searches and titles are not stored.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Generate a report when you want to see where your time went.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func usageRow(_ row: UsageReportRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.service == "Other" ? row.site : row.service).font(.body.bold())
                if row.service != "Other" { Text(row.site).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            Text(duration(row.seconds)).monospacedDigit()
        }.padding(.vertical, 5)
    }

    private func duration(_ seconds: Double) -> String {
        let value = Int(seconds.rounded())
        if value >= 3600 { return "\(value / 3600)h \((value % 3600) / 60)m" }
        if value >= 60 { return "\(value / 60)m \(value % 60)s" }
        return "\(value)s"
    }

    private func countdown(until end: Date, at date: Date) -> String {
        let hours = max(0, Int(end.timeIntervalSince(date))) / 3600
        return "\(hours / 24)d \(hours % 24)h left"
    }
}
