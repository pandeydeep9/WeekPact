import Foundation
import SwiftUI
import WeekPactCore

@main
struct WeekPactApp: App {
    @StateObject private var model = PlannerModel()

    var body: some Scene {
        WindowGroup("WeekPact") {
            PlannerView(model: model)
                .frame(minWidth: 820, minHeight: 680)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("WeekPact").font(.largeTitle.bold())
                Text("Planner prototype · No network enforcement yet")
                    .foregroundStyle(.orange)
                Text("Describe next week, then edit the exact rules before recording a plan.")
                TextEditor(text: $model.request)
                    .frame(height: 84)
                    .font(.body)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary))
                Button("Interpret request") { model.interpret() }
                    .buttonStyle(.borderedProminent)
                if !model.unparsed.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Not understood — edit or remove these clauses before saving:").bold()
                        ForEach(model.unparsed, id: \.self) { Text($0) }
                        Button("I corrected the rules") { model.unparsed = [] }
                    }.foregroundStyle(.orange)
                }

                Divider()
                HStack {
                    Text("Week of \(WeekClock.display(model.weekStart, timeZoneID: model.zone))")
                        .font(.title2.bold())
                    Spacer()
                    Button("This week") { model.prepareThisWeek() }
                    Button("Next week") { model.prepareNextWeek() }
                }
                Text("Time zone: \(model.zone)").foregroundStyle(.secondary)

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

                ForEach($model.rules) { $rule in
                    RuleEditor(rule: $rule)
                }
                Button("Add service") { model.addService() }
                Divider()
                Text("Review the dates, domains, and limits. Saving records a policy but does not block websites in this prototype.")
                    .font(.callout)
                Button("Record plan") { model.save() }
                    .buttonStyle(.borderedProminent)
                Text(model.status).font(.callout).foregroundStyle(.secondary)
            }
            .padding(24)
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
        GroupBox(rule.id.capitalized) {
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
