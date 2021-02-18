/// EOSIO ABI Definition.

import Foundation

/// Type describing a EOSIO ABI definition.
public struct ABI: Equatable, Hashable {
    /// The ABI definition version.
    public let version: String
    /// List of type aliases.
    public var types: [TypeDef]
    /// List of variant types.
    public var variants: [Variant]
    /// List of struct types.
    public var structs: [Struct]
    /// List of contract actions.
    public var actions: [Action]
    /// List of contract tables.
    public var tables: [Table]
    /// Ricardian contracts.
    public var ricardianClauses: [Clause]

    /// Create ABI definition.
    public init(
        types: [TypeDef] = [],
        variants: [Variant] = [],
        structs: [Struct] = [],
        actions: [Action] = [],
        tables: [Table] = [],
        ricardianClauses: [Clause] = []
    ) {
        self.version = "eosio::abi/1.1"
        self.types = types
        self.variants = variants
        self.structs = structs
        self.actions = actions
        self.tables = tables
        self.ricardianClauses = ricardianClauses
    }

    /// Create ABI definition from a binary representation.
    public init(binary data: Data) throws {
        let decoder = ABIDecoder()
        self = try decoder.decode(ABI.self, from: data)
    }

    /// Create ABI definition from a JSON representation.
    public init(json data: Data) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self = try decoder.decode(ABI.self, from: data)
    }

    public final class ResolvedType: Hashable, CustomStringConvertible {
        public static func == (lhs: ABI.ResolvedType, rhs: ABI.ResolvedType) -> Bool {
            lhs.typeName == rhs.typeName
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(self.typeName)
        }

        public let name: String
        public let flags: Flags

        public var parent: ResolvedType?
        public var builtIn: BuiltIn?
        public var variant: [ResolvedType]?
        public var fields: [(name: String, type: ResolvedType)]?
        public var other: ResolvedType?

        public enum BuiltIn: String {
            case string
            case bool
            case bytes
            case int8
            case int16
            case int32
            case int64
            case uint8
            case uint16
            case uint32
            case uint64
            case float32
            case float64
            case varint32
            case varuint32
            case name
            case asset
            case extended_asset
            case symbol
            case symbol_code
            case checksum256
            case public_key
            case signature
            case time_point
            case time_point_sec
        }

        public struct Flags: OptionSet {
            public let rawValue: UInt8
            public init(rawValue: UInt8) { self.rawValue = rawValue }
            public static let optional = Flags(rawValue: 1 << 0)
            public static let array = Flags(rawValue: 1 << 1)
            public static let binaryExt = Flags(rawValue: 1 << 2)
        }

        init(_ name: String) {
            var name = name
            var flags: Flags = []
            if name.hasSuffix("$") {
                name.removeLast()
                flags.insert(.binaryExt)
            }
            if name.hasSuffix("?") {
                name.removeLast()
                flags.insert(.optional)
            }
            if name.hasSuffix("[]") {
                name.removeLast(2)
                flags.insert(.array)
            }
            self.name = name
            self.flags = flags
        }

        var typeName: String {
            var rv = self.name
            if self.flags.contains(.array) {
                rv += "[]"
            }
            if self.flags.contains(.optional) {
                rv += "?"
            }
            if self.flags.contains(.binaryExt) {
                rv += "$"
            }
            return rv
        }

        public var description: String {
            var rv = self.typeName
            if self.variant != nil {
                rv += "(variant: \(self.variant!.map { $0.typeName }.joined(separator: " ")))"
            } else if self.fields != nil {
                rv += "(struct: \(self.fields!.map { "\($0.name)=\($0.type.typeName)" }.joined(separator: " ")))"
            } else if self.other != nil {
                rv += "(alias: \(self.other!.typeName))"
            } else if self.builtIn != nil {
                rv += "(builtin: \(self.builtIn!))"
            }
            return rv
        }
    }

    public func resolveType(_ name: String) -> ResolvedType {
        var seen = [String: ResolvedType]()
        return self.resolveType(name, nil, &seen)
    }

    func resolveType(_ name: String, _ parent: ResolvedType?, _ seen: inout [String: ResolvedType]) -> ResolvedType {
        let type = ResolvedType(name)
        type.parent = parent
        if let existing = seen[type.typeName] {
            type.other = existing
            return type
        }
        seen[type.typeName] = type
        if let alias = self.types.first(where: { $0.newTypeName == type.name }) {
            type.other = self.resolveType(alias.type, type, &seen)
        } else if let fields = self.resolveStruct(type.name) {
            type.fields = fields.map { ($0.name, self.resolveType($0.type, type, &seen)) }
        } else if let variant = self.getVariant(type.name) {
            type.variant = variant.types.map { self.resolveType($0, parent, &seen) }
        } else if let builtIn = ResolvedType.BuiltIn(rawValue: type.name) {
            type.builtIn = builtIn
        }
        return type
    }

    public func resolveStruct(_ name: String) -> [ABI.Field]? {
        var top = self.getStruct(name)
        if top == nil { return nil }
        var rv: [ABI.Field] = []
        var seen = Set<String>()
        repeat {
            rv.insert(contentsOf: top!.fields, at: 0)
            seen.insert(top!.name)
            if seen.contains(top!.base) {
                return nil // circular ref
            }
            top = self.getStruct(top!.base)
        } while top != nil
        return rv
    }

    public func getStruct(_ name: String) -> ABI.Struct? {
        return self.structs.first { $0.name == name }
    }

    public func getVariant(_ name: String) -> ABI.Variant? {
        return self.variants.first { $0.name == name }
    }

    public func getAction(_ name: Name) -> ABI.Action? {
        return self.actions.first { $0.name == name }
    }
}

// MARK: ABI Definition Types

public extension ABI {
    struct TypeDef: ABICodable, Equatable, Hashable {
        public let newTypeName: String
        public let type: String

        public init(_ newTypeName: String, _ type: String) {
            self.newTypeName = newTypeName
            self.type = type
        }
    }

    struct Field: ABICodable, Equatable, Hashable {
        public let name: String
        public let type: String

        public init(_ name: String, _ type: String) {
            self.name = name
            self.type = type
        }
    }

    struct Struct: ABICodable, Equatable, Hashable {
        public let name: String
        public let base: String
        public let fields: [Field]

        public init(_ name: String, _ fields: [Field]) {
            self.name = name
            self.base = ""
            self.fields = fields
        }

        public init(_ name: String, _ base: String, _ fields: [Field]) {
            self.name = name
            self.base = base
            self.fields = fields
        }
    }

    struct Action: ABICodable, Equatable, Hashable {
        public let name: Name
        public let type: String
        public let ricardianContract: String

        public init(_ nameAndType: Name, ricardian: String = "") {
            self.name = nameAndType
            self.type = String(nameAndType)
            self.ricardianContract = ricardian
        }

        public init(_ name: Name, _ type: String, ricardian: String = "") {
            self.name = name
            self.type = type
            self.ricardianContract = ricardian
        }
    }

    struct Table: ABICodable, Equatable, Hashable {
        public let name: Name
        public let indexType: String
        public let keyNames: [String]
        public let keyTypes: [String]
        public let type: String

        public init(_ name: Name, _ type: String, _ indexType: String, _ keyNames: [String] = [], _ keyTypes: [String] = []) {
            self.name = name
            self.type = type
            self.indexType = indexType
            self.keyNames = keyNames
            self.keyTypes = keyTypes
        }
    }

    struct Clause: ABICodable, Equatable, Hashable {
        public let id: String
        public let body: String

        public init(_ id: String, _ body: String) {
            self.id = id
            self.body = body
        }
    }

    struct Variant: ABICodable, Equatable, Hashable {
        public let name: String
        public let types: [String]

        public init(_ name: String, _ types: [String]) {
            self.name = name
            self.types = types
        }
    }

    private struct ErrorMessage: ABICodable, Equatable, Hashable {
        let errorCode: UInt64
        let errorMsg: String
    }
}

// MARK: ABI Coding

extension ABI: ABICodable {
    enum CodingKeys: String, CodingKey {
        // matches byte order
        case version
        case types
        case structs
        case actions
        case tables
        case ricardianClauses
        case errorMessages
        case abiExtensions
        case variants
    }

    public init(from decoder: Decoder) throws {
        // lenient decoding for poorly formed abi json files
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "eosio::abi/1.1"
        self.types = try container.decodeIfPresent([ABI.TypeDef].self, forKey: .types) ?? []
        self.structs = try container.decodeIfPresent([ABI.Struct].self, forKey: .structs) ?? []
        self.actions = try container.decodeIfPresent([ABI.Action].self, forKey: .actions) ?? []
        self.tables = try container.decodeIfPresent([ABI.Table].self, forKey: .tables) ?? []
        self.ricardianClauses = try container.decodeIfPresent([ABI.Clause].self, forKey: .ricardianClauses) ?? []
        self.variants = try container.decodeIfPresent([ABI.Variant].self, forKey: .variants) ?? []
    }

    public init(fromAbi decoder: ABIDecoder) throws {
        self.version = try decoder.decode(String.self)
        self.types = try decoder.decode([ABI.TypeDef].self)
        self.structs = try decoder.decode([ABI.Struct].self)
        self.actions = try decoder.decode([ABI.Action].self)
        self.tables = try decoder.decode([ABI.Table].self)
        self.ricardianClauses = try decoder.decode([ABI.Clause].self)
        _ = try decoder.decode([ABI.ErrorMessage].self) // ignore error messages, used only by abi compiler
        _ = try decoder.decode([Never].self) // abi extensions not used
        // decode variant typedefs (Y U NO USE EXTENSIONS?!)
        do {
            self.variants = try decoder.decode([ABI.Variant].self)
        } catch ABIDecoder.Error.prematureEndOfData {
            self.variants = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.version, forKey: .version)
        try container.encode(self.types, forKey: .types)
        try container.encode(self.structs, forKey: .structs)
        try container.encode(self.actions, forKey: .actions)
        try container.encode(self.tables, forKey: .tables)
        try container.encode(self.ricardianClauses, forKey: .ricardianClauses)
        try container.encode([] as [Never], forKey: .errorMessages)
        try container.encode([] as [Never], forKey: .abiExtensions)
        try container.encode(self.variants, forKey: .variants)
    }
}

// MARK: Language extensions

extension ABI.TypeDef: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self = ABI.TypeDef(array: elements)
    }

    fileprivate init(array elements: [String]) {
        guard elements.count == 2 else {
            fatalError("Invalid ABI typedef literal")
        }
        self = ABI.TypeDef(elements[0], elements[1])
    }
}

extension ABI.Action: ExpressibleByStringLiteral {
    public init(stringLiteral string: String) {
        self = ABI.Action(Name(string))
    }
}

extension ABI.Action: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self = ABI.Action(array: elements)
    }

    fileprivate init(array elements: [String]) {
        switch elements.count {
        case 2:
            self = ABI.Action(Name(elements[0]), elements[1])
        case 3:
            self = ABI.Action(Name(elements[0]), elements[1], ricardian: elements[2])
        default:
            fatalError("Invalid ABI action literal")
        }
    }
}

extension ABI.Field: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self = ABI.Field(array: elements)
    }

    fileprivate init(array elements: [String]) {
        guard elements.count == 2 else {
            fatalError("Invalid ABI field literal")
        }
        self = ABI.Field(elements[0], elements[1])
    }
}

extension ABI.Struct: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, [[String]])...) {
        guard elements.count == 1 else {
            fatalError("Invalid ABI struct literal")
        }
        self = ABI.Struct(elements[0].0, elements[0].1.map { ABI.Field(array: $0) })
    }
}

// MARK: ABI Definition

public extension ABI {
    /// The ABI definition for the ABI definition.
    static let abi = ABI(structs: [
        ["extensions_entry": [
            ["tag", "uint16"],
            ["value", "bytes"],
        ]],
        ["type_def": [
            ["new_type_name", "string"],
            ["type", "string"],
        ]],
        ["field_def": [
            ["name", "string"],
            ["type", "string"],
        ]],
        ["struct_def": [
            ["name", "string"],
            ["base", "string"],
            ["fields", "field_def[]"],
        ]],
        ["action_def": [
            ["name", "name"],
            ["type", "string"],
            ["ricardian_contract", "string"],
        ]],
        ["table_def": [
            ["name", "name"],
            ["index_type", "string"],
            ["key_names", "string[]"],
            ["key_types", "string[]"],
            ["type", "string"],
        ]],
        ["clause_pair": [
            ["id", "string"],
            ["body", "string"],
        ]],
        ["error_message": [
            ["error_code", "uint64"],
            ["error_msg", "string"],
        ]],
        ["variant_def": [
            ["name", "string"],
            ["types", "string[]"],
        ]],
        ["abi_def": [
            ["version", "string"],
            ["types", "type_def[]"],
            ["structs", "struct_def[]"],
            ["actions", "action_def[]"],
            ["tables", "table_def[]"],
            ["ricardian_clauses", "clause_pair[]"],
            ["error_messages", "error_message[]"],
            ["abi_extensions", "extensions_entry[]"],
            ["variants", "variant_def[]$"],
        ]],
    ])
}
