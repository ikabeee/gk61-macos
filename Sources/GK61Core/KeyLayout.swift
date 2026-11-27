import Foundation

/// Physical key layout, generated from the Windows driver's `00F7-2/Cfg.ini` `[KEY]` table.
public struct KeyLayout: Decodable, Sendable {
    public let name: String
    public let keys: [Key]

    public static func gk61() throws -> KeyLayout {
        guard let url = Bundle.module.url(forResource: "gk61-layout", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(KeyLayout.self, from: Data(contentsOf: url))
    }

    public func key(labeled label: String) -> Key? {
        keys.first { $0.label == label }
    }
}

extension KeyLayout {
    public struct Key: Decodable, Sendable, Hashable, Identifiable {
        public let label: String
        public let frame: Frame
        /// Slot in the firmware key matrix (entry offset = index × 6).
        public let matrixIndex: Int
        /// HID keyboard usage the key sends when not remapped; nil for the Fn key.
        public let defaultUsage: UInt8?
        public let isFn: Bool

        public var id: Int { matrixIndex }

        enum CodingKeys: CodingKey {
            case label, frame, matrixIndex, defaultUsage, isFn
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            label = try container.decode(String.self, forKey: .label)
            frame = try container.decode(Frame.self, forKey: .frame)
            matrixIndex = try container.decode(Int.self, forKey: .matrixIndex)
            defaultUsage = try container.decodeIfPresent(UInt8.self, forKey: .defaultUsage)
            isFn = try container.decodeIfPresent(Bool.self, forKey: .isFn) ?? false
        }
    }

    /// Key rectangle in the Windows app's pixel coordinates, stored as `[x, y, width, height]`.
    public struct Frame: Decodable, Sendable, Hashable {
        public let x: Int
        public let y: Int
        public let width: Int
        public let height: Int

        public init(from decoder: any Decoder) throws {
            var values = try decoder.unkeyedContainer()
            x = try values.decode(Int.self)
            y = try values.decode(Int.self)
            width = try values.decode(Int.self)
            height = try values.decode(Int.self)
        }
    }
}
