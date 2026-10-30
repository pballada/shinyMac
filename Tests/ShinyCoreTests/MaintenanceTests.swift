import Foundation
import Testing
@testable import ShinyCore

@Suite struct MaintenanceTests {
    @Test func taskIdentifiersAreUnique() {
        #expect(Set(Maintenance.tasks.map(\.id)).count == Maintenance.tasks.count)
    }

    @Test func batchScriptMarksEveryTask() {
        let tasks = Maintenance.tasks.filter(\.needsAdmin)
        let script = Maintenance.batchScript(for: tasks)
        for task in tasks {
            #expect(script.contains("#ok:\(task.id)"))
            #expect(script.contains("#fail:\(task.id)"))
        }
    }

    @Test func parsesBatchOutput() {
        let tasks = Array(Maintenance.tasks.filter(\.needsAdmin).prefix(3))
        let output = "#ok:\(tasks[0].id)\n#fail:\(tasks[1].id)\n"
        let outcomes = Maintenance.parseBatchOutput(output, tasks: tasks)
        #expect(outcomes[tasks[0].id] == .success)
        #expect(outcomes[tasks[1].id] == .failed("The command reported an error"))
        #expect(outcomes[tasks[2].id] == .failed("Didn't run"))
    }

    @Test func batchScriptRunsUnprivileged() throws {
        // The batching itself works with harmless commands.
        let fake = [
            MaintenanceTask(id: "a", title: "", detail: "", symbol: "", needsAdmin: true, recommended: true, command: "true"),
            MaintenanceTask(id: "b", title: "", detail: "", symbol: "", needsAdmin: true, recommended: true, command: "false"),
        ]
        let result = try Shell.run("/bin/sh", ["-c", Maintenance.batchScript(for: fake)])
        let outcomes = Maintenance.parseBatchOutput(result.output, tasks: fake)
        #expect(outcomes["a"] == .success)
        #expect(outcomes["b"] == .failed("The command reported an error"))
    }
}
