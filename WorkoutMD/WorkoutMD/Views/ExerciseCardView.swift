import SwiftUI

struct ExerciseCardView: View {
    @ObservedObject var exercise: Exercise
    var onRemove: (() -> Void)? = nil
    var onSetDone: (() -> Void)? = nil
    @State private var showingVideo = false
    @State private var showingProgression = false

    var body: some View {
        Section {
            ForEach($exercise.sets) { $set in
                SetRowView(set: $set, onSetDone: onSetDone)
            }
            Button {
                exercise.addSet()
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        } header: {
            HStack {
                Button {
                    showingProgression = true
                } label: {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
                .buttonStyle(.plain)
                Spacer()
                if exercise.videoURL != nil {
                    Button {
                        showingVideo = true
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingVideo) {
            if let url = exercise.videoURL {
                VideoPlayerView(url: url)
            }
        }
        .sheet(isPresented: $showingProgression) {
            NavigationStack {
                ExerciseProgressionView(exerciseName: exercise.name)
            }
        }
    }
}
