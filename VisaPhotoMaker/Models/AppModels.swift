import Foundation

struct CreationRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let country: String
    let format: String
    let layout: String
    let createdAt: Date
    let imageFilename: String?
    let fileFilename: String?

    init(
        id: UUID = UUID(),
        title: String,
        country: String,
        format: String,
        layout: String,
        createdAt: Date = Date(),
        imageFilename: String? = nil,
        fileFilename: String? = nil
    ) {
        self.id = id
        self.title = title
        self.country = country
        self.format = format
        self.layout = layout
        self.createdAt = createdAt
        self.imageFilename = imageFilename
        self.fileFilename = fileFilename
    }
}

@MainActor
final class LocalProfileStore: ObservableObject {
    @Published var isLoggedIn: Bool {
        didSet { defaults.set(isLoggedIn, forKey: Keys.isLoggedIn) }
    }
    @Published var username: String {
        didSet { defaults.set(username, forKey: Keys.username) }
    }
    @Published var avatarData: Data? {
        didSet { defaults.set(avatarData, forKey: Keys.avatarData) }
    }
    @Published private(set) var records: [CreationRecord]

    static let shared = LocalProfileStore()

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    private enum Keys {
        static let isLoggedIn = "localProfile.isLoggedIn"
        static let username = "localProfile.username"
        static let avatarData = "localProfile.avatarData"
        static let records = "localProfile.records"
    }

    private init() {
        self.isLoggedIn = defaults.bool(forKey: Keys.isLoggedIn)
        self.username = defaults.string(forKey: Keys.username) ?? "Guest"
        self.avatarData = defaults.data(forKey: Keys.avatarData)
        if let data = defaults.data(forKey: Keys.records),
           let decoded = try? JSONDecoder().decode([CreationRecord].self, from: data) {
            self.records = decoded
        } else {
            self.records = []
        }
    }

    func login() {
        isLoggedIn = true
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            username = "Guest"
        }
    }

    func logout() {
        isLoggedIn = false
    }

    func addRecord(_ record: CreationRecord) {
        records.insert(record, at: 0)
        records = Array(records.prefix(50))
        persistRecords()
    }

    func clearRecords() {
        for record in records {
            deleteRecordFiles(record)
        }
        records.removeAll()
        persistRecords()
    }

    func imageURL(for record: CreationRecord) -> URL? {
        guard let imageFilename = record.imageFilename else { return nil }
        let url = recordsDirectory.appendingPathComponent(imageFilename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func fileURL(for record: CreationRecord) -> URL? {
        guard let fileFilename = record.fileFilename else { return nil }
        let url = recordsDirectory.appendingPathComponent(fileFilename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func saveRecordAssets(id: UUID, imageData: Data?, fileData: Data?, fileExtension: String) -> (imageFilename: String?, fileFilename: String?) {
        try? fileManager.createDirectory(at: recordsDirectory, withIntermediateDirectories: true)

        var savedImageFilename: String?
        if let imageData {
            let filename = "\(id.uuidString)-preview.jpg"
            let url = recordsDirectory.appendingPathComponent(filename)
            if (try? imageData.write(to: url, options: .atomic)) != nil {
                savedImageFilename = filename
            }
        }

        var savedFileFilename: String?
        if let fileData {
            let filename = "\(id.uuidString)-export.\(fileExtension)"
            let url = recordsDirectory.appendingPathComponent(filename)
            if (try? fileData.write(to: url, options: .atomic)) != nil {
                savedFileFilename = filename
            }
        }

        return (savedImageFilename, savedFileFilename)
    }

    private var recordsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("CreationRecords", isDirectory: true)
    }

    private func deleteRecordFiles(_ record: CreationRecord) {
        if let imageURL = imageURL(for: record) {
            try? fileManager.removeItem(at: imageURL)
        }
        if let fileURL = fileURL(for: record) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    private func persistRecords() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Keys.records)
        }
    }
}
