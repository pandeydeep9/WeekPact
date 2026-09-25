import Foundation
import SwiftUI
import WeekPactCore

@main
struct WeekPactApp: App {
    @StateObject private var model = PlannerModel()
    @StateObject private var trial = TrialController()
    @StateObject private var usage = UsageController()

    var body: some Scene {
        WindowGroup("WeekPact") {
            PlannerView(model: model, trial: trial, usage: usage)
                .frame(minWidth: 700, minHeight: 540)
        }
    }
}

@MainActor
final class PlannerModel: ObservableObject {
    @Published var request = "Next week, YouTube for 30 minutes a day after 6 PM. Netflix for 2 hours on Friday and Saturday. Block Reddit"
    @Published var rules: [Rule] = []
    @Published var unparsed: [String] = []
    @Published var status = "Preview only — website blocking is not installed."
    @Published var book: PolicyBook
    @Published var weekStart: Date

    let zone = TimeZone.current.identifier
    private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WeekPact", isDirectory: true)
        fileURL = folder.appendingPathComponent("policies.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(PolicyBook.self, from: data) {
            book = saved
        } else {
            book = PolicyBook()
        }
        weekStart = WeekClock.next(after: .now, timeZoneID: TimeZone.current.identifier)
    }

    func interpret() {
        let plan = PromptParser.parse(request)
        rules = plan.rules
        unparsed = plan.unparsed
        status = plan.unparsed.isEmpty
            ? "Draft ready. Review every rule before saving. Blocking is not installed."
            : "Some words could not be interpreted. Correct those clauses in the editor before saving."
    }

    func prepareNextWeek() {
        weekStart = WeekClock.next(after: .now, timeZoneID: zone)
        rules = book.effective(at: weekStart)?.rules ?? []
        unparsed = []
        status = "Editing next week. Blocking is not installed."
    }

    func prepareThisWeek() {
        weekStart = WeekClock.start(containing: .now, timeZoneID: zone)
        rules = book.effective(at: .now)?.rules ?? []
        unparsed = []
        status = "Changes to this week can only reduce access. Blocking is not installed."
    }

    func addService() {
        let next = (1...).first { index in !rules.contains(where: { $0.id == "service-\(index)" }) }!
        rules.append(Rule(id: "service-\(next)", domains: ["example.com"],
                          days: Set(Weekday.allCases), windows: [TimeWindow(startMinute: 0, endMinute: 1440)]))
    }

    func toggle(_ day: Weekday, for serviceID: String) {
        guard let index = rules.firstIndex(where: { $0.id == serviceID }) else { return }
        if rules[index].days.contains(day) {
            rules[index].days.remove(day)
        } else {
            rules[index].days.insert(day)
            if rules[index].windows.isEmpty {
                rules[index].windows = [TimeWindow(startMinute: 0, endMinute: 1440)]
            }
        }
    }

    func save() {
        guard unparsed.isEmpty else {
            status = "Resolve the unparsed clauses before saving."
            return
        }
        var updated = book
        let policy = WeeklyPolicy(weekStart: weekStart, timeZoneID: zone, rules: rules)
        do {
            let result = try updated.submit(policy, now: .now)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(updated)
            try data.write(to: fileURL, options: .atomic)
            _ = SharedPolicySnapshot.write(updated)
            book = updated
            switch result {
            case .committed(let date):
                status = "Plan recorded for \(WeekClock.display(date, timeZoneID: zone)). Blocking is not installed."
            case .scheduled(let date):
                status = "Weaker plan scheduled for \(WeekClock.display(date, timeZoneID: zone)). Blocking is not installed."
            }
        } catch {
            status = error.localizedDescription
        }
    }
}

struct PlannerView: View {
    @ObservedObject var model: PlannerModel
    @ObservedObject var trial: TrialController
    @ObservedObject var usage: UsageController
    @State private var page: Page = .today
    @State private var command = ""

    private enum Page: String, CaseIterable, Identifiable {
        case today = "Today", plan = "Plan", report = "Report"
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
                TextField("Type “generate report” or describe a rule", text: $command)
                    .onSubmit(runCommand)
                Button("Go", action: runCommand)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch page {
                    case .today: todayView
                    case .plan: planView
                    case .report: reportView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: 940)
        .frame(maxWidth: .infinity)
    }

    private func runCommand() {
        let input = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if input.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".!?")) == "generate report" {
            usage.generateReport()
            page = .report
        } else {
            model.request = input
            model.interpret()
            page = .plan
        }
        command = ""
    }

    private var todayView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today").font(.title2.bold())
                    Text("Website time on this Mac · \(TimeZone.current.identifier)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(usage.isTracking ? "Pause tracking" : "Resume tracking") {
                    usage.setTracking(!usage.isTracking)
                }
            }
            GroupBox("Website time") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(duration(usage.today.totalSeconds)).font(.largeTitle.bold()).monospacedDigit()
                    if usage.today.sites.isEmpty {
                        Text("No foreground website time recorded today.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(usage.today.sites.prefix(5)) { row in usageRow(row) }
                    }
                    HStack {
                        Button("Generate 7-day report") {
                            usage.generateReport()
                            page = .report
                        }.buttonStyle(.borderedProminent)
                        Spacer()
                        Text("Safari + Chrome · local only").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(8)
            }
            Text(usage.status).font(.callout).foregroundStyle(.secondary)
            GroupBox("YouTube trial · 5 minutes/day") {
                VStack(alignment: .leading, spacing: 10) {
                    if trial.isRunning {
                        ProgressView(value: 300 - trial.remainingSeconds, total: 300)
                        Text("\(Int(trial.remainingSeconds.rounded(.up))) seconds left today")
                            .font(.headline).monospacedDigit()
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(trial.resetDescription(at: timeline.date))
                                .font(.callout).monospacedDigit()
                        }
                        Button("End test now · allow YouTube") { trial.end() }
                    } else {
                        HStack {
                            Text("Off · YouTube available").foregroundStyle(.secondary)
                            Spacer()
                            Button("Start five-minute trial") { trial.start() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    DisclosureGroup("Trial details") {
                        TextField("Trial instruction", text: $trial.instruction)
                            .disabled(trial.isRunning)
                        Text("The five minutes refill at local midnight. This browser test is bypassable and is separate from weekly plans.")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(trial.status).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(8)
            }
            Label("Private-window coverage is unverified; unreadable tabs are omitted. Tracking stops if WeekPact quits.",
                  systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
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
                Text("Foreground website time").foregroundStyle(.secondary)
                if report.sites.isEmpty {
                    Text("No sites recorded in this period.")
                } else {
                    ForEach(report.sites) { row in usageRow(row) }
                }
                Text("Sites and time are saved in Application Support/WeekPact/usage.json on this Mac. Only domains, service, browser, dates, and time are stored; page paths, search terms, and titles are omitted.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Generate a report when you want to see where your time went. You can also type “generate report” above.")
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
        }
        .padding(.vertical, 5)
    }

    private func duration(_ seconds: Double) -> String {
        let value = Int(seconds.rounded())
        if value >= 3600 { return "\(value / 3600)h \((value % 3600) / 60)m" }
        if value >= 60 { return "\(value / 60)m \(value % 60)s" }
        return "\(value)s"
    }

    private var planView: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Plan your week").font(.title2.bold())
                Spacer()
                Text("Preview only · no blocking yet").font(.caption).foregroundStyle(.orange)
            }
            GroupBox("Describe your plan") {
                VStack(alignment: .leading, spacing: 10) {
                    TextEditor(text: $model.request)
                        .frame(height: 72)
                        .padding(6)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    Button("Preview rules") { model.interpret() }
                        .buttonStyle(.borderedProminent)
                }.padding(8)
            }
            if !model.unparsed.isEmpty {
                VStack(alignment: .leading) {
                    Text("Not understood — edit or remove these clauses before saving:").bold()
                    ForEach(model.unparsed, id: \.self) { Text($0) }
                    Button("I corrected the rules") { model.unparsed = [] }
                }.foregroundStyle(.orange)
            }
            HStack {
                Text("Week of \(WeekClock.display(model.weekStart, timeZoneID: model.zone))")
                    .font(.headline)
                Spacer()
                Button("This week") { model.prepareThisWeek() }
                Button("Next week") { model.prepareNextWeek() }
            }
            Text("Time zone: \(model.zone)").font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Service").frame(width: 130, alignment: .leading)
                    ForEach(Weekday.ordered) { day in
                        Text(day.shortName).frame(maxWidth: .infinity)
                    }
                }.font(.caption.bold())
                ForEach(model.rules) { rule in
                    HStack {
                        Text(rule.id.capitalized).frame(width: 130, alignment: .leading)
                        ForEach(Weekday.ordered) { day in
                            Button(summary(rule, day: day)) { model.toggle(day, for: rule.id) }
                                .font(.caption)
                                .buttonStyle(.borderless)
                                .help("Toggle \(day.shortName) for \(rule.id)")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            if model.rules.isEmpty {
                Text("Preview your request or add a service to begin.")
                    .foregroundStyle(.secondary)
            }
            ForEach($model.rules) { $rule in RuleEditor(rule: $rule) }
            Button("Add service") { model.addService() }
            HStack {
                Button("Record plan") { model.save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.rules.isEmpty)
                Text(model.status).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func summary(_ rule: Rule, day: Weekday) -> String {
        guard rule.days.contains(day), let window = rule.windows.first else { return "Blocked" }
        let limit = rule.dailySeconds.map { "\($0 / 60)m" } ?? "Open"
        if window.startMinute == 0 && window.endMinute == 1440 { return limit }
        return "\(limit) · \(window.startMinute / 60)–\(window.endMinute / 60)"
    }
}

struct RuleEditor: View {
    @Binding var rule: Rule

    private var domains: Binding<String> {
        Binding(get: { rule.domains.joined(separator: ", ") }, set: { value in
            rule.domains = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        })
    }

    private var isBlocked: Binding<Bool> {
        Binding(get: { rule.days.isEmpty || rule.windows.isEmpty }, set: { blocked in
            rule.days = blocked ? [] : Set(Weekday.allCases)
            rule.windows = blocked ? [] : [TimeWindow(startMinute: 0, endMinute: 1440)]
        })
    }

    private var allowance: Binding<Int> {
        Binding(get: { (rule.dailySeconds ?? 1800) / 60 },
                set: { rule.dailySeconds = $0 * 60 })
    }

    private var startsAt: Binding<Int> {
        Binding(get: { (rule.windows.first?.startMinute ?? 0) / 60 }, set: { hour in
            let end = max(hour + 1, rule.windows.first?.endMinute ?? 1440)
            rule.windows = [TimeWindow(startMinute: hour * 60, endMinute: end)]
        })
    }

    private var endsAt: Binding<Int> {
        Binding(get: { (rule.windows.first?.endMinute ?? 1440) / 60 }, set: { hour in
            let start = min((hour - 1) * 60, rule.windows.first?.startMinute ?? 0)
            rule.windows = [TimeWindow(startMinute: start, endMinute: hour * 60)]
        })
    }

    var body: some View {
        DisclosureGroup(rule.id.capitalized) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Service name", text: $rule.id)
                TextField("Domains, separated by commas", text: domains)
                Toggle("Blocked every day", isOn: isBlocked)
                if !isBlocked.wrappedValue {
                    HStack {
                        ForEach(Weekday.ordered) { day in
                            Toggle(day.shortName, isOn: Binding(
                                get: { rule.days.contains(day) },
                                set: { enabled in
                                    if enabled { rule.days.insert(day) } else { rule.days.remove(day) }
                                }
                            )).toggleStyle(.button)
                        }
                    }
                    Toggle("Daily allowance", isOn: Binding(
                        get: { rule.dailySeconds != nil },
                        set: { rule.dailySeconds = $0 ? 1800 : nil }
                    ))
                    if rule.dailySeconds != nil {
                        Stepper("\(allowance.wrappedValue) minutes per day", value: allowance, in: 0...480, step: 5)
                    }
                    HStack {
                        Stepper("From \(startsAt.wrappedValue):00", value: startsAt, in: 0...23)
                        Stepper("Until \(endsAt.wrappedValue):00", value: endsAt, in: 1...24)
                    }
                }
            }.padding(8)
        }
    }
}
