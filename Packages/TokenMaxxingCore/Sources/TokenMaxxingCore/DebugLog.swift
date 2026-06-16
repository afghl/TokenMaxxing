func tokenMaxxingDebugLog(_ message: @autoclosure () -> String) {
#if DEBUG
    print("[TokenMaxxing] \(message())")
#endif
}
