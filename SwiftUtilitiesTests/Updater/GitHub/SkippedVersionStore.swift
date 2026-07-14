/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import Foundation
@testable import SwiftUtilities
import Testing

struct Test_SkippedVersionStore
{
    /// A store backed by an isolated, temporary `UserDefaults` suite, together
    /// with the suite name so the caller can tear it down after use.
    private typealias Fixture = ( store: SkippedVersionStore, defaults: UserDefaults, suite: String )

    /// Builds a store backed by a fresh, empty `UserDefaults` suite unique to the
    /// calling test, so no test observes another's writes or the process defaults.
    private func makeFixture( owner: String = "apple", repository: String = "swift" ) throws -> Fixture
    {
        let suite    = "SkippedVersionStore.Tests.\( UUID().uuidString )"
        let defaults = try #require( UserDefaults( suiteName: suite ) )

        defaults.removePersistentDomain( forName: suite )

        let store = SkippedVersionStore( owner: owner, repository: repository, defaults: defaults )

        return ( store, defaults, suite )
    }

    @Test
    func readReturnsNilWhenNothingStored() throws
    {
        let fixture = try self.makeFixture()

        defer { fixture.defaults.removePersistentDomain( forName: fixture.suite ) }

        #expect( fixture.store.skippedVersion == nil )
    }

    @Test
    func setStoresVersion() throws
    {
        let fixture = try self.makeFixture()

        defer { fixture.defaults.removePersistentDomain( forName: fixture.suite ) }

        fixture.store.setSkippedVersion( "1.2.0" )

        #expect( fixture.store.skippedVersion == "1.2.0" )
    }

    @Test
    func setReplacesPreviousVersion() throws
    {
        let fixture = try self.makeFixture()

        defer { fixture.defaults.removePersistentDomain( forName: fixture.suite ) }

        fixture.store.setSkippedVersion( "1.2.0" )
        fixture.store.setSkippedVersion( "1.3.0" )

        #expect( fixture.store.skippedVersion == "1.3.0" )
    }

    @Test
    func clearRemovesStoredVersion() throws
    {
        let fixture = try self.makeFixture()

        defer { fixture.defaults.removePersistentDomain( forName: fixture.suite ) }

        fixture.store.setSkippedVersion( "1.2.0" )
        fixture.store.clearSkippedVersion()

        #expect( fixture.store.skippedVersion == nil )
    }

    @Test
    func keyIsNamespacedPerRepository() throws
    {
        let suite    = "SkippedVersionStore.Tests.\( UUID().uuidString )"
        let defaults = try #require( UserDefaults( suiteName: suite ) )

        defaults.removePersistentDomain( forName: suite )

        defer { defaults.removePersistentDomain( forName: suite ) }

        let first  = SkippedVersionStore( owner: "apple", repository: "swift",     defaults: defaults )
        let second = SkippedVersionStore( owner: "apple", repository: "swift-nio", defaults: defaults )

        #expect( first.key  == "GitHubUpdater.apple/swift.skippedVersion" )
        #expect( second.key == "GitHubUpdater.apple/swift-nio.skippedVersion" )

        first.setSkippedVersion( "1.0.0" )

        #expect( first.skippedVersion  == "1.0.0" )
        #expect( second.skippedVersion == nil )
    }
}
