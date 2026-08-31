//
//  EditPlaylistView.swift
//  flo
//

import SwiftUI

struct EditPlaylistView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var viewModel: AlbumViewModel

  @State private var name: String
  @State private var comment: String
  @State private var isPublic: Bool
  @State private var songs: [Song]
  @State private var errorMessage: String?
  @State private var editMode: EditMode = .active

  private let playlist: Playlist

  init(viewModel: AlbumViewModel, playlist: Playlist) {
    self.viewModel = viewModel
    self.playlist = playlist
    _name = State(initialValue: playlist.name)
    _comment = State(initialValue: playlist.comment)
    _isPublic = State(initialValue: playlist.isPublic)
    _songs = State(initialValue: playlist.songs)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Details") {
          TextField("Name", text: $name)
          TextField("Comment", text: $comment)
          Toggle("Public", isOn: $isPublic)
        }

        Section("Songs") {
          ForEach(songs) { song in
            VStack(alignment: .leading) {
              Text(song.title)
              Text(song.artist)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .onMove { songs.move(fromOffsets: $0, toOffset: $1) }
          .onDelete { songs.remove(atOffsets: $0) }
        }
      }
      .navigationTitle("Edit Playlist")
      .environment(\.editMode, $editMode)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
          Button("Save") { save() }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .alert(
        "Unable to Update Playlist",
        isPresented: Binding(
          get: { errorMessage != nil },
          set: { if !$0 { errorMessage = nil } }
        )
      ) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage ?? "")
      }
    }
  }

  private func save() {
    let songsChanged = songs.map(\.id) != playlist.songs.map(\.id)
    AlbumService.shared.updatePlaylist(
      id: playlist.id,
      name: name.trimmingCharacters(in: .whitespacesAndNewlines),
      comment: comment,
      isPublic: isPublic
    ) { result in
      if case .success = result, songsChanged {
        AlbumService.shared.reorderPlaylist(
          id: playlist.id,
          songIds: songs.map(\.id),
          currentSongCount: playlist.songs.count,
          completion: finish)
      } else {
        finish(result)
      }
    }
  }

  private func finish(_ result: Result<Void, Error>) {
      DispatchQueue.main.async {
        switch result {
        case .success:
          let updated = Playlist(
            id: playlist.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            comment: comment,
            isPublic: isPublic,
            ownerName: playlist.ownerName,
            coverArtId: playlist.coverArtId,
            songs: songs
          )
          viewModel.playlist = updated
          if let index = viewModel.playlists.firstIndex(where: { $0.id == playlist.id }) {
            viewModel.playlists[index] = updated
          }
          Task { await viewModel.refreshPlaylists() }
          dismiss()
        case .failure(let error):
          errorMessage = error.localizedDescription
        }
      }
  }
}
