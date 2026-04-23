//
//  FolderAccessManager.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 4/23/26.
//

import Foundation
import Combine

#if os(macOS)
import AppKit

class FolderAccessManager: ObservableObject {
    @Published var folders: [AccessedFolder] = []
    @Published var selectedFolder: AccessedFolder? = nil

    private let storageKey = "InsightFlow.FolderBookmarks"

    struct AccessedFolder: Identifiable {
        let id: UUID
        let url: URL
        let bookmark: Data

        var name: String { url.lastPathComponent }
    }

    init() {
        loadBookmarks()
    }

    // MARK: - Select / Deselect

    func select(_ folder: AccessedFolder) {
        // Stop access to whatever was previously selected
        if let current = selectedFolder {
            current.url.stopAccessingSecurityScopedResource()
        }

        // Start access to the newly selected folder
        guard folder.url.startAccessingSecurityScopedResource() else {
            print("Failed to gain access to \(folder.url.path)")
            selectedFolder = nil
            return
        }

        selectedFolder = folder
    }

    func deselect() {
        selectedFolder?.url.stopAccessingSecurityScopedResource()
        selectedFolder = nil
    }

    // MARK: - Open Folder Picker

    func pickFolder(completion: ((AccessedFolder?) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Choose a folder to give Claude access to"

        panel.begin { [weak self] (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else {
                completion?(nil)
                return
            }
            let folder = self?.addFolder(url: url)
            // Auto-select the newly picked folder
            if let folder {
                self?.select(folder)
            }
            completion?(folder)
        }
    }

    // MARK: - Add / Remove

    @discardableResult
    func addFolder(url: URL) -> AccessedFolder? {
        if folders.contains(where: { $0.url == url }) { return nil }

        do {
            let bookmark = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let folder = AccessedFolder(id: UUID(), url: url, bookmark: bookmark)
            DispatchQueue.main.async {
                self.folders.append(folder)
                self.saveBookmarks()
            }
            return folder
        } catch {
            print("Failed to create bookmark for \(url.path): \(error)")
            return nil
        }
    }

    func removeFolder(_ folder: AccessedFolder) {
        // If the removed folder is currently selected, deselect it first
        if selectedFolder?.id == folder.id {
            deselect()
        }
        folders.removeAll { $0.id == folder.id }
        saveBookmarks()
    }

    func revealInFinder(_ folder: AccessedFolder) {
        // Temporarily access just to reveal, then stop
        guard folder.url.startAccessingSecurityScopedResource() else { return }
        NSWorkspace.shared.open(folder.url)
        folder.url.stopAccessingSecurityScopedResource()
    }

    // MARK: - Persistence

    private func saveBookmarks() {
        let bookmarks = folders.map { $0.bookmark }
        UserDefaults.standard.set(bookmarks, forKey: storageKey)
    }

    private func loadBookmarks() {
        // Just resolve the URLs — do NOT start access yet.
        // Access only begins when the user explicitly selects a folder.
        guard let saved = UserDefaults.standard.array(forKey: storageKey) as? [Data] else { return }

        var loaded: [AccessedFolder] = []
        for bookmarkData in saved {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                guard !isStale else { continue }
                loaded.append(AccessedFolder(id: UUID(), url: url, bookmark: bookmarkData))
            } catch {
                print("Failed to resolve bookmark: \(error)")
            }
        }
        self.folders = loaded
    }
}

#endif
