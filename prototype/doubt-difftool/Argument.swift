enum Argument {
	indirect case File(Source, Argument)
	indirect case OutputFlag(Output, Argument)
	case End

	var rest: Argument? {
		switch self {
		case let .File(_, rest):
			return rest
		case let .OutputFlag(_, rest):
			return rest
		case .End:
			return nil
		}
	}

	var files: [Source] {
		switch self {
		case let .File(a, rest):
			return [a] + rest.files
		default:
			return rest?.files ?? []
		}
	}

	enum Output {
		case Unified
		case Split
	}
}

let argumentsParser: Madness.Parser<[String], Argument>.Function = none()


import Madness
