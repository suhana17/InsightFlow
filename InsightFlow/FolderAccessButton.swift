//
//  FolderAccessButton.swift
//  InsightFlow
//
//  Created by Rayyan Anwar on 4/23/26.
//

import SwiftUI

struct FolderAccessButton: View {
    @ObservedObject var manager: FolderAccessManager

    @State private var showPopover = false
    @State private var folderToDelete: FolderAccessManager.AccessedFolder? = nil
    @State private var showDeleteConfirm = false

    private var hasfolders: Bool { !manager.folders.isEmpty }

    var body: some View {
        Button {
            if hasfolders {
                showPopover.toggle()
            } else {
                manager.pickFolder()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasfolders ? "folder.fill" : "folder.badge.plus")
                    .imageScale(.medium)
                Text(buttonLabel)
                    .fontWeight(.medium)
                if hasfolders {
                    Image(systemName: "chevron.down")
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            folderDropdown
        }
        .alert("Remove Access", isPresented: $showDeleteConfirm, presenting: folderToDelete) { folder in
            Button("Remove", role: .destructive) {
                manager.removeFolder(folder)
            }
            Button("Cancel", role: .cancel) {}
        } message: { folder in
            Text("Remove Claude's access to \"\(folder.name)\"?")
        }
    }

    // MARK: - Dropdown

    private var folderDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {

            ForEach(manager.folders) { folder in
                folderRow(folder)
            }

            Divider()
                .padding(.top, 4)

            Button {
                showPopover = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    manager.pickFolder()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Add Folder")
                        .foregroundColor(.accentColor)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 260)
        .padding(.bottom, 4)
    }

    // MARK: - Folder Row

    private func folderRow(_ folder: FolderAccessManager.AccessedFolder) -> some View {
        let isSelected = manager.selectedFolder?.id == folder.id

        return HStack(spacing: 10) {

            // Checkmark — only visible on the active folder
            Image(systemName: "checkmark")
                .imageScale(.small)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .opacity(isSelected ? 1 : 0)
                .frame(width: 14)

            Image(systemName: "folder.fill")
                .foregroundColor(.accentColor)
                .imageScale(.medium)

            Text(folder.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fontWeight(isSelected ? .semibold : .regular)

            // Reveal in Finder
            Button {
                manager.revealInFinder(folder)
            } label: {
                Image(systemName: "magnifyingglass.circle")
                    .imageScale(.medium)
                    .foregroundColor(.secondary)
                    .padding(5)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Show in Finder")

            // Remove access
            Button {
                folderToDelete = folder
                showDeleteConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .imageScale(.medium)
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Remove access")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        // Highlight the selected row
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        // Tap the row to select
        .onTapGesture {
            manager.select(folder)
            showPopover = false
        }
    }

    // MARK: - Helpers

    private var buttonLabel: String {
        if let selected = manager.selectedFolder {
            return selected.name          // show whichever is selected
        }
        if hasfolders {
            return manager.folders[0].name // fallback: first folder before any selection
        }
        return "Give Access"
    }
}
