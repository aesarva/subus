import Testing
@testable import SubusCore

@Suite struct UpdateErrorsTests {
    @Test func diskImageAndTranslocationAskToMove() {
        #expect(UpdateErrors.event(sparkleCode: 1003, message: "x", userInitiated: false) == .locationUnsupported)
        #expect(UpdateErrors.event(sparkleCode: 1005, message: "x", userInitiated: true) == .locationUnsupported)
    }

    @Test func otherErrorsKeepMessageAndOrigin() {
        #expect(UpdateErrors.event(sparkleCode: 2001, message: "network", userInitiated: true)
            == .error(message: "network", userInitiated: true))
        #expect(UpdateErrors.event(sparkleCode: nil, message: "network", userInitiated: false)
            == .error(message: "network", userInitiated: false))
    }

    @Test func cycleOutcome() {
        #expect(UpdateErrors.cycleOutcome(failed: false, sparkleCode: nil) == .succeeded)
        #expect(UpdateErrors.cycleOutcome(failed: true, sparkleCode: 1001) == .succeeded)   // no update
        #expect(UpdateErrors.cycleOutcome(failed: true, sparkleCode: 4007) == .installCanceled)
        #expect(UpdateErrors.cycleOutcome(failed: true, sparkleCode: 2001) == .failed)
        #expect(UpdateErrors.cycleOutcome(failed: true, sparkleCode: nil) == .failed)
    }
}
