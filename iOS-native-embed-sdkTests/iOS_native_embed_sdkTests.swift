//
//  iOS_native_embed_sdkTests.swift
//  iOS-native-embed-sdkTests
//
//  Created by Prashant.patil on 09/04/25.
//


import Testing
@testable import iOS_native_embed_sdk

struct iOS_native_embed_sdkTests {

    @Test func example() async throws {
        #expect(true)
    }

    @Test func testAddition() async throws {
        let result = 1 + 1
        #expect(result == 2, "1 + 1 should equal 2")
    }

    @Test func testBaseEmbedController() async throws {
        #expect(true)
    }
}
