import Foundation

enum FileDrawerPlace: String, CaseIterable, Identifiable {
    case downloads, documents, desktop, applications, home, pictures, music, movies
    case `public`, utilities, library, volumes

    var id: Self { self }

    func title(_ chinese: Bool) -> String {
        switch self {
        case .downloads: chinese ? "下载" : "Downloads"
        case .documents: chinese ? "文稿" : "Documents"
        case .desktop: chinese ? "桌面" : "Desktop"
        case .applications: chinese ? "应用程序" : "Applications"
        case .home: chinese ? "主文件夹" : "Home"
        case .pictures: chinese ? "图片" : "Pictures"
        case .music: chinese ? "音乐" : "Music"
        case .movies: chinese ? "影片" : "Movies"
        case .public: chinese ? "公共" : "Public"
        case .utilities: chinese ? "实用工具" : "Utilities"
        case .library: chinese ? "资源库" : "Library"
        case .volumes: chinese ? "宗卷" : "Volumes"
        }
    }

    var symbol: String {
        switch self {
        case .downloads: "arrow.down.circle"
        case .documents: "doc"
        case .desktop: "desktopcomputer"
        case .applications: "square.grid.2x2"
        case .home: "house"
        case .pictures: "photo"
        case .music: "music.note"
        case .movies: "film"
        case .public: "person.2"
        case .utilities: "wrench.and.screwdriver"
        case .library: "books.vertical"
        case .volumes: "externaldrive"
        }
    }

    func directory(in home: URL) -> URL {
        switch self {
        case .home: home
        case .applications: URL(fileURLWithPath: "/Applications", isDirectory: true)
        case .utilities: URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true)
        case .volumes: URL(fileURLWithPath: "/Volumes", isDirectory: true)
        default: home.appendingPathComponent(rawValue.capitalized, isDirectory: true)
        }
    }
}
