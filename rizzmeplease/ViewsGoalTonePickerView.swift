//
//  GoalTonePickerView.swift
//  TextCoach
//
//  View for selecting conversation goal and tone
//

import SwiftUI

struct GoalTonePickerView: View {
    @Binding var selectedGoal: Goal?
    @Binding var selectedTone: Tone?
    let onGenerate: () async -> Void
    
    @State private var isGenerating = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Goal Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("What's your goal?")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        ForEach(Goal.allCases, id: \.self) { goal in
                            GoalCard(
                                goal: goal,
                                isSelected: selectedGoal == goal,
                                action: { selectedGoal = goal }
                            )
                        }
                    }
                }
                
                // Tone Selection
                VStack(alignment: .leading, spacing: 15) {
                    Text("Choose your tone")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Tone.allCases, id: \.self) { tone in
                            ToneCard(
                                tone: tone,
                                isSelected: selectedTone == tone,
                                action: { selectedTone = tone }
                            )
                        }
                    }
                }
                
                // Generate Button
                Button(action: {
                    Task {
                        isGenerating = true
                        await onGenerate()
                        isGenerating = false
                    }
                }) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isGenerating ? "Generating..." : "Generate Suggestions")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canGenerate ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canGenerate || isGenerating)
            }
            .padding()
        }
    }
    
    private var canGenerate: Bool {
        selectedGoal != nil && selectedTone != nil
    }
}

struct GoalCard: View {
    let goal: Goal
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : goalColor)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.displayName)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    Text(goal.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(isSelected ? goalColor : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? goalColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var goalColor: Color {
        switch goal {
        case .getReply: return .blue
        case .askMeetup: return .purple
        case .setBoundary: return .orange
        }
    }
}

struct ToneCard: View {
    let tone: Tone
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: tone.icon)
                    .font(.title)
                    .foregroundStyle(isSelected ? .blue : .primary)
                
                Text(tone.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .blue : .primary)
                
                Text(tone.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GoalTonePickerView(
        selectedGoal: .constant(.getReply),
        selectedTone: .constant(.friendly),
        onGenerate: { }
    )
}
