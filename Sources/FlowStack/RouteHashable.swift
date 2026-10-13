import Foundation

/// Configuration for prototype-only reflection fallback diagnostics.
public enum FlowRouteIDDiagnostics {
    private static let configuration = Configuration()

    /// Thread-safe logging toggle. Fallback identity is only suitable for prototyping.
    public static var warnsOnFallbackID: Bool {
        get { configuration.lock.withLock { configuration.enabled } }
        set { configuration.lock.withLock { configuration.enabled = newValue } }
    }

    private final class Configuration: @unchecked Sendable {
        let lock = NSLock()
        var enabled = true
    }
}

/// Route equality and hashing based on a String ID; useful for non-Hashable payloads.
/// Override id for production: IDs must distinguish semantic routes and stay stable
/// for the lifetime of a stored route. Callbacks are excluded from equality.
/// The reflection fallback is for prototypes; it is not a persistence format and
/// can collide for ambiguous payload descriptions.
public protocol RouteHashable: Hashable, Identifiable where ID == String {}

public extension RouteHashable {
    var id: String {
        FlowRouteID.make(from: self)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private enum FlowRouteID {
    static func make(from value: Any) -> String {
        let mirror = Mirror(reflecting: value)

        if mirror.displayStyle == .enum {
            return enumID(from: value, mirror: mirror)
        }

        // Calling componentID on the route itself would call its default id recursively.
        if let child = mirror.children.first(where: { $0.label == "id" }) {
            return componentID(from: child.value) ?? String(reflecting: child.value)
        }
        if FlowRouteIDDiagnostics.warnsOnFallbackID {
            debugPrint("FlowStack warning: Override RouteHashable.id for stable production route identity.")
        }
        return String(reflecting: value)
    }

    private static func enumID(from value: Any, mirror: Mirror) -> String {
        guard let child = mirror.children.first else {
            return String(describing: value)
        }

        let caseName = child.label ?? String(describing: value)
        let parameters = tupleComponents(from: child.value)

        guard !parameters.isEmpty else {
            return caseName
        }

        return "\(caseName)(\(parameters.joined(separator: ",")))"
    }

    private static func tupleComponents(from value: Any) -> [String] {
        let mirror = Mirror(reflecting: value)

        guard mirror.displayStyle == .tuple else {
            return componentID(from: value).map { [$0] } ?? []
        }

        return mirror.children.compactMap { child in
            guard let component = componentID(from: child.value) else { return nil }
            guard let label = child.label, !label.hasPrefix(".") else { return component }
            return "\(label):\(component)"
        }
    }

    private static func componentID(from value: Any) -> String? {
        if let value = value as? String { return value }
        if let value = value as? UUID { return value.uuidString }
        if let value = value as? URL { return value.absoluteString }
        if let value = value as? Bool { return String(value) }
        if let value = value as? Int { return String(value) }
        if let value = value as? Int8 { return String(value) }
        if let value = value as? Int16 { return String(value) }
        if let value = value as? Int32 { return String(value) }
        if let value = value as? Int64 { return String(value) }
        if let value = value as? UInt { return String(value) }
        if let value = value as? UInt8 { return String(value) }
        if let value = value as? UInt16 { return String(value) }
        if let value = value as? UInt32 { return String(value) }
        if let value = value as? UInt64 { return String(value) }
        if let value = value as? Float { return String(value) }
        if let value = value as? Double { return String(value) }
        if let value = value as? any RouteHashable { return value.id }

        let description = String(describing: value)
        if description == "(Function)" || description.contains("(Function)") {
            return nil
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return "nil" }
            return componentID(from: child.value)
        }

        if let idChild = mirror.children.first(where: { $0.label == "id" }) {
            return componentID(from: idChild.value) ?? String(describing: idChild.value)
        }

        if FlowRouteIDDiagnostics.warnsOnFallbackID {
            debugPrint("FlowStack warning: RouteHashable generated id from String(describing:) for \(type(of: value)). Override id for stable production route identity.")
        }

        return description
    }
}

/// Base route for subclass payloads whose identity is an explicit immutable String.
open class AnyRouteHashable: RouteHashable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}
