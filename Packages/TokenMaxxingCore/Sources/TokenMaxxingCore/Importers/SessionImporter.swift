public protocol SessionImporter {
    func importSessions() throws -> [Session]
    func importSession(id: Session.ID) throws -> Session?
}
