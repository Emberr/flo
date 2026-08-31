//
//  PlaylistView.swift
//  flo
//
//  Created by rizaldy on 15/11/24.
//

import SwiftUI

struct PlaylistView: View {
  @EnvironmentObject private var viewModel: AlbumViewModel
  @EnvironmentObject private var playerViewModel: PlayerViewModel
  @EnvironmentObject private var downloadViewModel: DownloadViewModel

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  @State private var searchPlaylist = ""
  @State private var showDownloadSheet: Bool = false
  @State private var showCreatePlaylist = false
  @State private var playlistName = ""
  @State private var playlistToDelete: Playlist?
  @State private var errorMessage: String?

  private var columns: [GridItem] {
    if horizontalSizeClass == .regular {
      return Array(repeating: GridItem(.flexible()), count: 4)
    } else {
      return Array(repeating: GridItem(.flexible()), count: 2)
    }
  }

  var filteredPlaylists: [Playlist] {
    if searchPlaylist.isEmpty {
      return viewModel.playlists
    } else {
      return viewModel.playlists.filter { playlist in
        playlist.name.localizedCaseInsensitiveContains(searchPlaylist)
      }
    }
  }

  var body: some View {
    ScrollView {
      LazyVGrid(columns: columns) {
        ForEach(filteredPlaylists) { playlist in
          NavigationLink {
            PlaylistDetailView()
              .environmentObject(viewModel)
              .environmentObject(playerViewModel)
              .environmentObject(downloadViewModel)
              .onAppear {
                viewModel.setActivePlaylist(playlist: playlist)
              }
          } label: {
            PlaylistsView(viewModel: viewModel, playlist: playlist)
          }
          .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) {
              playlistToDelete = playlist
            }
          }
        }
      }
      .padding(.top, 10)
      .padding(
        .bottom, playerViewModel.hasNowPlaying() && !playerViewModel.shouldHidePlayer ? 100 : 0
      )
    }
    .toolbar {
      Button("New Playlist", systemImage: "plus") {
        showCreatePlaylist = true
      }

      if downloadViewModel.hasDownloadQueue() {
        Button(action: {
          showDownloadSheet.toggle()
        }) {
          Label("", systemImage: "icloud.and.arrow.down")
        }
      }
    }
    .sheet(isPresented: $showDownloadSheet) {
      DownloadQueueView().environmentObject(downloadViewModel)
    }
    .alert("New Playlist", isPresented: $showCreatePlaylist) {
      TextField("Name", text: $playlistName)
      Button("Cancel", role: .cancel) {
        playlistName = ""
      }
      Button("Create") {
        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        AlbumService.shared.createPlaylist(name: name) { result in
          DispatchQueue.main.async {
            switch result {
            case .success:
              playlistName = ""
              Task { await viewModel.refreshPlaylists() }
            case .failure(let error):
              errorMessage = error.localizedDescription
            }
          }
        }
      }
      .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .confirmationDialog(
      "Delete \(playlistToDelete?.name ?? "playlist")?",
      isPresented: Binding(
        get: { playlistToDelete != nil },
        set: { if !$0 { playlistToDelete = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        guard let playlist = playlistToDelete else { return }
        AlbumService.shared.deletePlaylist(id: playlist.id) { result in
          DispatchQueue.main.async {
            playlistToDelete = nil
            switch result {
            case .success:
              Task { await viewModel.refreshPlaylists() }
            case .failure(let error):
              errorMessage = error.localizedDescription
            }
          }
        }
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
    .navigationTitle("Playlists")
    .refreshable {
      await viewModel.refreshPlaylists()
    }
    .searchable(
      text: $searchPlaylist, placement: .navigationBarDrawer(displayMode: .always),
      prompt: "Search")
  }
}
