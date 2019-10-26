@testable import EOSIO
import XCTest

let base64_base58_pairs = [
    ("AuZJ9j+OgSE0X9f0fQ0YWjzKqEMRXNLpOS3Nm4ImO8aA", "6dumtt9swxCqwdPZBGXh9YmHoEjFFnNfwHaTqRbQTghGAY2gRz", true),
    ("AhxzWc2IXA4xmSTZfjmAIGrWQ4ev9UkIJBEls6iLVcoW", "5725vivYpuFWbeyTifZ5KevnHyqXCi5hwHbNU9cYz1FHbFXCxX", true),
    ("AvVh4LV6VS3z+h3y2HqQa3qfwzqD1dFfpopkTssIBrSa", "6kZKHSuxqAwdCYsMvwTcipoTsNE2jmEUNBQufGYywpniBKXWZK", true),
    ("A+dZXD5rWPkHvulR3Cl5bzdXMH5wDs89CTB6DMSlZOuj", "8b82mpnH8YX1E9RHnU2a2YgLTZ8ooevEGP9N15c1yFqhoBvJur", true),
    ("AGWhYFmGSi/bx8maRyOoOVvG8Yjr", "1AGNa15ZQXAZUgFiqJ2i7Z2DPU2J6hW62i", false),
    ("BXTyCfbqkH4upI90+uBXgq6KZlJX", "3CMNFxN1oHBc4R1EpboAL5yzHGgE611Xou", false),
    ("b1PAMH1oUaoM54JbqIPGvZrSQrSG", "mo9ncXisMeAoXwqcV5EWuyncbmCcQN4rVs", false),
    ("xGNJpBj8RXjRCjcrVLRcKAzIxDgv", "2N2JD6wb56AfK4tfmM6PwdVmoYk2dCKf4Br", false),
    ("gO3b3BFo8drq29PkTB4/j1ooTCAp94rSavmFg6SZ3lsZ", "5Kd3NBUAdUnhyzenEwVLy9pBKxSwXvE9FMPyR4UKZvpe6E3AgLr", false),
    ("gFXJvMue1oRG0bdSc7vOidf+ATqKzRYlUUQg+yrKGiHEAQ==", "Kz6UJmQACJmLtaQj5A3JAge4kVTNQ8gbvXuwbmCj7bsaabudb3RD", false),
    ("7zbLk7mrG9q/f7nywE8bnMh5kzUwrnhCOY7vWmOlaADC", "9213qJab2HNEpMpYNBa7wHGFKKbkDn24jpANDs2huN3yi4J11ko", false),
    ("77n0iSyegoICj+odJmfE3FITVk1B/FeDiWoNhD/BUInzAQ==", "cTpB4YiyKiBcPxnefsDpbnDxFDffjqJob8wGCEDXxgQ7zQoMXJdH", false),
    ("AG0jFWy73MgqWkfu5MLHxYPBi2v0", "1Ax4gZtb7gAit2TivwejZHYtNNLT18PUXJ", false),
    ("BfzFRg3W4kh8fXWxljYl2g6PTFl1", "3QjYXhTkvuj8qPaXHTTWb5wjXhdsLAAWVy", false),
    ("b/HUcPmwI3D97C5rcIsIrEMb96X3", "n3ZddxzLvAY9o7184TB4c6FJasAybsw4HZ", false),
    ("xMV5NCwsTJIgIF4s3ChWFwQMkkoK", "2NBFNJTktNa7GZusGbDbGKRZTxdK9VVez3n", false),
    ("gKMmuV664wFkIX16f1fXKrK1TjvmSSihnaAhC5Vo1AFe", "5K494XZwps2bGyeL71pWid4noiSNA2cfCibrvRWqcHSptoFn7rc", false),
    ("gH2Zi0XCGaHjjpnny9MS72f3ekVam1DHMMJ/Asb3MN+0AQ==", "L1RrrnXkcKut5DEMwtDthjwRcTTwED36thyL1DebVrKuwvohjMNi", false),
    ("79a8ola1q8VgLsLhwSGgiw2iVWWHQwvPfhiYryIkiFID", "93DVKyFYwSN6wEo3E2fCrFPUp17FtrtNi2Lf7n4G3garFb16CRj", false),
    ("76gcpOj5AYHsS2G2p+uZivF7LLBN6KA7UEueNMTGHbfZAQ==", "cTDVKtMGVYWTHCb1AFjmVbEbWjvKpKqKgMaR3QJxToMSQAhmCeTN", false),
    ("AHmHzKpT0CyIc0h++RlnfNPbemkS", "1C5bSj1iEGUgSTbziymG7Cn18ENQuT36vv", false),
    ("BWO8xWX55o7gGJ3VzGfxsOXwL0XL", "3AnNxabYGoTxYiTEZwFEnerUoeFXK2Zoks", false),
    ("b+9mREtbF/FOj65ufhmwRaeMVP15", "n3LnJXCqbPjghuVs8ph9CYsAe4Sh4j97wk", false),
    ("xMPlX87OqkOR7SqWd/Sk006s0CGg", "2NB72XtkjpnATMggui83aEtPawyyKvnbX2o", false),
    ("gOddk21WN39DL0BKq7QGYB+JL9SdqQ62rFWKczyTtHJS", "5KaBW9vNtWNhc3ZEDyNCiXLPdVPHCikRxSBWwV9NrpLLa4LsXi9", false),
    ("gIJIvQN18vddfidK5UT7kg9ReESAhmsQI4QZCxrd+6pcAQ==", "L1axzbSyynNYA8mCAhzxkipKkfHtAXYF4YQnhSKcLV8YXA874fgT", false),
    ("70TE9qCW6sUjgpGpTMJMAeOxm42M73KHSgeeAKJCI3pS", "927CnUkUbasYtDwYwVn2j8GdTuACNnKkjZ1rpZd2yBB1CLcnXpo", false),
    ("79HecHAgqQWdbTq6+F4XlnxlVRURQ9sT27Btt43w8VxpAQ==", "cUcfCMRjiQf85YMzzQEk9d1s5A4K7xL5SmBCLrezqXFuTVefyhY7", false),
    ("AK3BzCCBonIG+uJXkvKLvFW4MVSd", "1Gqk4Tv79P91Cc1STQtU3s1W6277M2CVWu", false),
    ("BRiPkakxlH7d10MtbmFDh+MrJEcJ", "33vt8ViH5jsr115AGkW6cEmEz9MpvJSwDk", false),
    ("bxaU9bwacpW2APQAGKYYpupI7rSY", "mhaMcBxNh5cqXm4aTQ6EcVbKtfL6LGyK2H", false),
    ("xDubP9elDU8I0aWw9i9kT6cRWuLz", "2MxgPqX1iThW3oZVk9KoFcE5M4JpiETssVN", false),
    ("gAkQNURe8QX6G7El7M+xiC8/5pWSJllWredR/QlQM9jQ", "5HtH6GdcwCJA4ggWEL1B3jzBBUB8HPiBi9SBc5h9i4Wk4PSeApR", false),
    ("gKsrS838kdNN7griqMa2Zo2trrOoi5hZdDFW9GIyUYevAQ==", "L2xSYmMeVo3Zek3ZTsv9xUrXVAmrWxJ8Ua4cw8pkfbQhcEFhkXT8", false),
    ("77QgQ4nO8Yu+KzU2I8v5PoZ4+8kqR1tmSumO1ZTmzwhW", "92xFEve1Z9N8Z641KQQS7ByCSb8kGjsDzw6fAmjHN1LZGKQXyMq", false),
    ("7+eyMBM/G1SJhDJgI2sG7col9mrbG+RV+9ONQBDUj67vAQ==", "cVM65tdYu1YK37tNoAyGoJTR13VBYFva1vg9FLuPAsJijGvG6NEA", false),
    ("AMTBtySR7eHu2soAYYQH7gt3LK0N", "1JwMWBVLtiqtscbaRHai4pqHokhFCbtoB4", false),
    ("Bfb+aby1SKgpzOTFe/b/+K86WYH5", "3QCzvfL4ZRvmJFiWWBVwxfdaNBT8EtxB5y", false),
    ("byYfg1aKCYqGOIRL167KA51fI1LA", "mizXiucXRCsEriQCHUkCqef9ph9qtPbZZ6", false),
    ("xOkw4YNKTSNHAnc5UdYnzOgvu10u", "2NEWDzHWwY5ZZp8CQWbB7ouNMLqCia6YRda", false),
    ("gNH6t6tzha0mhyI38euXiaolzJhrrMaV4HrFcdbNrIvA", "5KQmDryMNDcisTzRp3zEq9e4awRmJrEVU1j5vFRTKpRNYPqYrMg", false),
    ("gLC77eM+8lToN2rOsVECU/w1UO/Q/PhNzQyZmLKI8WazAQ==", "L39Fy7AC2Hhj95gh3Yb2AU5YHh1mQSAHgpNixvm27poizcJyLtUi", false),
    ("7wN/QZLGMPOZ2SceJsV1JpsdFb5VPqGnIX8MuFE870HL", "91cTVUcgydqyZLgaANpf1fvL55FH53QMm4BsnCADVNYuWuqdVys", false),
    ("72JR4gXorVCLq1WWvuCG7xbNSyOeDMDF18TmA1RB59XeAQ==", "cQspfSzsgLeiJGB2u8vrAiWpCU4MxUT6JseWo2SjXy4Qbzn2fwDw", false),
    ("AF6tr5u3Eh8PGSVhpaYvXl9UIQKS", "19dcawoKcZdQz365WpXWMhX6QCUpR9SY4r", false),
    ("BT8hDnJ3yJnDoVXMHJD0EGy93uxu", "37Sp6Rv3y4kVd1nQ1JV5pfqXccHNyZm1x3", false),
    ("b8ijwqCaKYWSw+GA8CSHzZG6NAC1", "myoqcgYiehufrsnnkqdqbp69dddVDMopJu", false),
    ("xJmzHffJBo0UgbWWV43btNO9kLrr", "2N7FuwuUuoTBrDFdrAZ9KxBmtqMLxce9i1C", false),
    ("gMdmaEJQPbbcbqBh8JLPucOIRIYppv6GjQaMQqSItHiu", "5KL6zEaMtPRXZKo1bbMq7JDjjo1bJuQcsgL33je3oY8uSJCR5b4", false),
    ("gAfwgD/FOZ53NVWrHok5kH6brazBfKEp5novXy/4Q1HdAQ==", "KwV9KAfwbwt51veZWNscRTeZs9CKpojyu1MsPnaKTF5kz69H1UN2", false),
    ("7+pXes+10dFNO3sZXDIVZvEvh9K3fqOlP2jffr+GBKgB", "93N87D6uxSBzwXvpokpzg8FFmfQPmvX4xHoWQe3pLdYpbiwT5YV", false),
    ("7ws7NPCVjYomgZOpgU2pLD6LWLSkN4pUKGPjSsKJzYMMAQ==", "cMxXusSihaX58wpJ3tNuuUcZEQGt6DKJ1wEpxys88FFaQCYjku9h", false),
    ("AB7UZwF/BD6R7UxEtOjdZ02yEcTm", "13p1ijLwsnrcuyqcTvJXkq2ASdXqcnEBLE", false),
    ("BV7ODK3dxBWxmA8AF4WUcSCs2zb8", "3ALJH9Y951VCGcVZYAdpA3KchoP9McEj1G", false),
    ("gCzyTbpfsKMOJug7KsW54p4bFh5cH6dCXnMEM2KTi5gk", "5JA5gN4G78DhFSW4jr28vjb8JEX5UhVMZB16Jr6MjDGaeguJEvm", false),
    ("A4fYIELZNEcAjf4q92IGih5T/zlKW/j2igRfpkK5nqXR", "7s4VJuYFfHq8HCPpgC649Lu7CjA1V9oXgPfv8f3fszKMk3Kny9", true),
]

class Base58Test: XCTestCase {
    func testRipemd160() {
        XCTAssertEqual(
            "".utf8Data.ripemd160Digest,
            "9c1185a5c5e9fc54612808977ee8f548b2258d31"
        )
        XCTAssertEqual(
            "The quick brown fox jumps over the lazy dog".utf8Data.ripemd160Digest,
            "37f332f68db77bd9d7edd4969571ad671cf9dd3b"
        )
        XCTAssertEqual(
            "The quick brown fox jumps over the lazy cog".utf8Data.ripemd160Digest,
            "132072df690933835eb8b6ad0b77e7b6f14acad7"
        )
    }

    func testDecode() {
        for (b64, b58, graphene) in base64_base58_pairs {
            let checksumType: Data.Base58CheckType = graphene ? .ripemd160 : .sha256d
            let data = Data(base58CheckEncoded: b58, checksumType)
            XCTAssertEqual(data?.base64EncodedString(), b64)
        }
        XCTAssertEqual(Data(base58Encoded: "StV1DL6CwTryKyV"), "hello world".data(using: .utf8))
    }

    func testEncode() {
        for (b64, b58, graphene) in base64_base58_pairs {
            let checksumType: Data.Base58CheckType = graphene ? .ripemd160 : .sha256d
            let data = Data(base64Encoded: b64)!
            XCTAssertEqual(data.base58CheckEncodedString(checksumType), b58)
        }
        XCTAssertEqual("hello world".data(using: .utf8)!.base58EncodedString(), "StV1DL6CwTryKyV")
    }

    func testLargeEncode() {
        let bigly = Data(repeating: 42, count: 4 * 1000)
        XCTAssertNotNil(bigly.base58EncodedString())
        measure {
            _ = bigly.base58EncodedString()
        }
    }

    func testLargeDecode() {
        let bigly = Data(repeating: 42, count: 4 * 1000)
        guard let encoded = bigly.base58EncodedString() else {
            XCTFail()
            return
        }
        XCTAssertEqual(bigly, Data(base58Encoded: encoded))
        measure {
            _ = Data(base58Encoded: encoded)
        }
    }
}
