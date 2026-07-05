import Carbon
import Foundation

final class InputSourceChangeObserver {
    private var handler: (() -> Void)?
    private var isStarted = false

    deinit {
        stop()
    }

    func start(handler: @escaping () -> Void) {
        guard !isStarted else { return }
        self.handler = handler
        InputLockerLog.inputSource.info("input source observer start")

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                let instance = Unmanaged<InputSourceChangeObserver>
                    .fromOpaque(observer)
                    .takeUnretainedValue()
                InputLockerLog.inputSource.debug("input source changed notification")
                instance.handler?()
            },
            kTISNotifySelectedKeyboardInputSourceChanged,
            nil,
            .deliverImmediately
        )

        isStarted = true
    }

    func stop() {
        guard isStarted else { return }
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDistributedCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
        handler = nil
        isStarted = false
        InputLockerLog.inputSource.info("input source observer stop")
    }
}
