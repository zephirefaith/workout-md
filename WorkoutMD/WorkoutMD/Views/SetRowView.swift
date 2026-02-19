import SwiftUI

struct SetRowView: View {
    @Binding var set: WorkoutSet
    var onSetDone: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                set.isDone.toggle()
                if set.isDone { onSetDone?() }
            } label: {
                Image(systemName: set.isDone ? "checkmark.square.fill" : "square")
                    .foregroundStyle(set.isDone ? .green : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Weight field
            TextField("Weight", text: $set.weight)
                .textFieldStyle(.plain)
                .keyboardType(.default)
                .autocorrectionDisabled()
                .frame(minWidth: 80)
                .strikethrough(set.isDone, color: .secondary)
                .foregroundStyle(set.isDone ? .secondary : .primary)

            Spacer()

            // Reps stepper
            HStack(spacing: 4) {
                Button {
                    if set.reps > 1 { set.reps -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Text("\(set.reps)")
                    .font(.body.monospacedDigit())
                    .frame(minWidth: 28, alignment: .center)
                    .strikethrough(set.isDone, color: .secondary)
                    .foregroundStyle(set.isDone ? .secondary : .primary)

                Button {
                    set.reps += 1
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            Text("reps")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
