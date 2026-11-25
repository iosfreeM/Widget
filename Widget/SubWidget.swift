import WidgetKit
import SwiftUI

struct SubEntry: TimelineEntry {
    let date: Date
    let tgSubs: String
    let ttSubs: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SubEntry {
        SubEntry(date: Date(), tgSubs: "...", ttSubs: "...")
    }

    func getSnapshot(in context: Context, completion: @escaping (SubEntry) -> ()) {
        completion(SubEntry(date: Date(), tgSubs: "...", ttSubs: "..."))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SubEntry>) -> ()) {
        Task {
            let tgCount = await fetchTelegramSubs(username: "mtech2027")
            let ttCount = await fetchTikTokSubs(username: "mtechap")

            let entry = SubEntry(date: Date(), tgSubs: tgCount, ttSubs: ttCount)
            // Обновление раз в 30 минут
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }

    // Парсинг Telegram (t.me/s/mtech2027)
    func fetchTelegramSubs(username: String) async -> String {
        guard let url = URL(string: "https://t.me/s/\(username)") else { return "—" }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let html = String(data: data, encoding: .utf8) {
                let pattern = #"<div class="tgme_header_counter">([^<]+)</div>"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    let raw = String(html[range])
                    return raw.replacingOccurrences(of: " subscribers", with: "")
                              .replacingOccurrences(of: " subscriber", with: "")
                              .trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {}
        return "—"
    }

    // Парсинг TikTok (@mtechap)
    func fetchTikTokSubs(username: String) async -> String {
        guard let url = URL(string: "https://www.tiktok.com/@\(username)") else { return "—" }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let html = String(data: data, encoding: .utf8) {
                let pattern = #""followerCount":(\d+)"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html),
                   let count = Int(html[range]) {
                    return formatNumber(count)
                }
            }
        } catch {}
        return "—"
    }

    func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return "\(num)"
    }
}

struct SubWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Telegram")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(entry.tgSubs)
                        .font(.system(size: 15, weight: .bold))
                }
            }
            
            Divider()
            
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .foregroundColor(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("TikTok")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(entry.ttSubs)
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
        .padding(.horizontal, 2)
    }
}

@main
struct SubWidget: Widget {
    let kind: String = "SubWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                SubWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                SubWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Мои подписчики")
        .description("Telegram и TikTok в одном виджете.")
        .supportedFamilies([.systemSmall])
    }
}
