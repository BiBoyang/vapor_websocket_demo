actor SocketContext {
    private var userId: String?

    func setUserId(_ userId: String) {
        self.userId = userId
    }

    func getUserId() -> String? {
        userId
    }
}
