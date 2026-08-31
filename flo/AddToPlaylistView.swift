//
//  AddToPlaylistView.swift
//  flo
//

import SwiftUI

struct AddToPlaylistView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var viewModel: AlbumViewModel
  let song: Song

  @State private var playlistName = ""
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      List {
        Section("New Playlist") {
          TextField("Name", text: $playlistName)
          Button("Create") {
            createPlaylist()
          }
          .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        Section("Playlists") {
          ForEach(viewModel.playlists) { playlist in
            Button(playlist.name) {
              addSong(to: playlist)
            }
          }
        }
      }
      .navigationTitle("Add to Playlist")
      .toolbar {
        Button("Cancel", role: .cancel) {
          dismiss()
        }
      }
      .task {
        viewModel.getPlaylists()
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

  private func createPlaylist() {
    let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
    AlbumService.shared.createPlaylist(name: name, songIds: [song.id]) {
      handle($0)
    }
  }

  private func addSong(to playlist: Playlist) {
    AlbumService.shared.updatePlaylist(id: playlist.id, songIdsToAdd: [song.id]) {
      handle($0)
    }
  }

  private func handle(_ result: Result<Void, Error>) {
    DispatchQueue.main.async {
      switch result {
      case .success:
        Task { await viewModel.refreshPlaylists() }
        dismiss()
      case .failure(let error):
        errorMessage = error.localizedDescription
      }
    }
  }
}
