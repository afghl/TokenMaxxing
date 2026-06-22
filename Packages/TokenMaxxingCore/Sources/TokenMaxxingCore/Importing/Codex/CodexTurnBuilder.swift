import Foundation

struct CodexTurnBuilder {
    func buildTurns(from events: [NumberedCodexEvent], sessionID: String) -> [Turn] {
        let turnWindows = turnWindows(from: events)

        return turnWindows.enumerated().map { offset, turnWindow in
            let window = Array(events[turnWindow.startIndex..<turnWindow.endIndex])
            let beforeUsage = Array(events[..<turnWindow.startIndex]).lastUsageSnapshot
            let latestUsage = window.lastUsageSnapshot
            let usage = latestUsage?.subtracting(beforeUsage)
            let completedAt = window.first { $0.isEventMessage("task_complete") }?.event.timestamp
            let messages = window.compactMap { makeMessage(from: $0, sessionID: sessionID) }

            return Turn(
                id: "\(sessionID)-turn-\(offset + 1)",
                startedAt: events[turnWindow.startIndex].event.timestamp,
                completedAt: completedAt,
                messages: messages,
                usage: usage
            )
        }
    }

    private func turnWindows(from events: [NumberedCodexEvent]) -> [CodexTurnWindow] {
        let taskStartIndices = events.indices.filter { events[$0].isEventMessage("task_started") }
        guard !taskStartIndices.isEmpty else {
            return userMessageWindows(from: events)
        }

        return taskStartIndices.enumerated().compactMap { offset, taskStartIndex in
            let nextTaskStartIndex = taskStartIndices.dropFirst(offset + 1).first ?? events.endIndex
            let taskCompleteEndIndex = events[taskStartIndex..<nextTaskStartIndex]
                .firstIndex(where: { $0.isEventMessage("task_complete") })
                .map { events.index(after: $0) }
            let taskEndIndex = taskCompleteEndIndex ?? nextTaskStartIndex

            guard let firstUserMessageIndex = events[taskStartIndex..<taskEndIndex]
                .firstIndex(where: { $0.isEventMessage("user_message") })
            else {
                return nil
            }

            return CodexTurnWindow(startIndex: firstUserMessageIndex, endIndex: taskEndIndex)
        }
    }

    private func userMessageWindows(from events: [NumberedCodexEvent]) -> [CodexTurnWindow] {
        let userEventIndices = events.indices.filter { events[$0].isEventMessage("user_message") }

        return userEventIndices.enumerated().map { offset, startIndex in
            let endIndex = userEventIndices.dropFirst(offset + 1).first ?? events.endIndex
            return CodexTurnWindow(startIndex: startIndex, endIndex: endIndex)
        }
    }

    private func makeMessage(from event: NumberedCodexEvent, sessionID: String) -> Message? {
        let rawType = event.rawType
        let messageID = "\(sessionID):\(event.line)"

        if event.event.type == "event_msg" {
            switch event.event.payload?.type {
            case "user_message":
                return Message(
                    id: messageID,
                    role: .user,
                    timestamp: event.event.timestamp,
                    preview: event.event.payload?.message?.trimmedCodexPreview(),
                    rawType: rawType,
                    sourceLine: event.line
                )
            case "agent_message":
                return Message(
                    id: messageID,
                    role: .assistant,
                    timestamp: event.event.timestamp,
                    preview: event.event.payload?.message?.trimmedCodexPreview(),
                    rawType: rawType,
                    sourceLine: event.line
                )
            case "token_count":
                return Message(
                    id: messageID,
                    role: .internal,
                    timestamp: event.event.timestamp,
                    usageSnapshot: event.usageSnapshot,
                    rawType: rawType,
                    sourceLine: event.line
                )
            case .some:
                return Message(
                    id: messageID,
                    role: .internal,
                    timestamp: event.event.timestamp,
                    rawType: rawType,
                    sourceLine: event.line
                )
            case .none:
                return nil
            }
        }

        guard event.event.type == "response_item" else {
            return nil
        }

        switch event.event.payload?.type {
        case "function_call":
            return Message(
                id: messageID,
                role: .tool,
                timestamp: event.event.timestamp,
                preview: event.event.payload?.name?.trimmedCodexPreview(),
                rawType: rawType,
                sourceLine: event.line
            )
        case "function_call_output":
            return Message(
                id: messageID,
                role: .tool,
                timestamp: event.event.timestamp,
                rawType: rawType,
                sourceLine: event.line
            )
        case "reasoning":
            return Message(
                id: messageID,
                role: .internal,
                timestamp: event.event.timestamp,
                rawType: rawType,
                sourceLine: event.line
            )
        default:
            return nil
        }
    }
}

private struct CodexTurnWindow {
    let startIndex: Array<NumberedCodexEvent>.Index
    let endIndex: Array<NumberedCodexEvent>.Index
}

private extension String {
    func trimmedCodexPreview(limit: Int = 160) -> String {
        let normalized = split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard normalized.count > limit else {
            return normalized
        }

        let end = normalized.index(normalized.startIndex, offsetBy: limit)
        return String(normalized[..<end])
    }
}
