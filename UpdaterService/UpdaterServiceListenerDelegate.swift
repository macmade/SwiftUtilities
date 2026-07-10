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

#if canImport( Security )
import Security
#endif

/// Accepts and configures incoming connections to the updater service.
///
/// For each connection it first verifies the peer is the trusted host application
/// (same Team ID, by audit token — see ``XPCClientVerifier``) and refuses anything
/// else. It then wires the bidirectional interfaces, builds the ``UpdaterService``
/// exported object with the production building blocks, and routes install progress
/// back to the connection's client proxy.
final class UpdaterServiceListenerDelegate: NSObject, NSXPCListenerDelegate
{
    /// Verifies and configures a new connection.
    ///
    /// - Parameters:
    ///   - listener:      The service listener.
    ///   - newConnection: The incoming connection.
    ///
    /// - Returns: `true` if the connection was accepted and configured; `false` to
    ///   reject an untrusted peer.
    func listener( _ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection ) -> Bool
    {
        guard self.isTrustedClient( newConnection )
        else
        {
            return false
        }

        newConnection.exportedInterface     = NSXPCInterface( with: UpdaterServiceProtocol.self )
        newConnection.remoteObjectInterface = NSXPCInterface( with: UpdaterClientProtocol.self )

        let service = UpdaterService(
            extractor:      ArchiveExtractor(),
            inspector:      SecurityCodeSignatureInspector(),
            replacer:       AppReplacer(),
            makeRelauncher: { ProcessRelauncher( processIdentifier: $0 ) },
            reportProgress: UpdaterServiceListenerDelegate.progressSink( for: newConnection )
        )

        newConnection.exportedObject = service

        newConnection.resume()

        return true
    }

    /// Builds a progress sink that forwards each phase to the connection's client.
    ///
    /// The install runs on a background task, so the sink is `@Sendable`; the
    /// connection is boxed in an ``UnsafeSendable`` to cross that boundary (sending
    /// on an XPC proxy is thread-safe). Each phase is encoded and delivered one-way.
    ///
    /// - Parameter connection: The connection whose client should receive progress.
    ///
    /// - Returns: A sink that streams ``InstallProgress`` to the client.
    private static func progressSink( for connection: NSXPCConnection ) -> @Sendable ( InstallProgress ) -> Void
    {
        let box = UnsafeSendable( connection )

        let sink: @Sendable ( InstallProgress ) -> Void =
        {
            progress in

            guard let client = box.value.remoteObjectProxy as? UpdaterClientProtocol,
                  let data   = try? progress.encoded()
            else
            {
                return
            }

            client.updateDidProgress( data )
        }

        return sink
    }

    /// Reports whether the connecting peer is the trusted host application.
    ///
    /// Requires the peer to be signed by the same Team ID as this service, verified
    /// by its audit token. Without the Security framework, or if the peer cannot be
    /// resolved, the connection is refused.
    ///
    /// - Parameter connection: The incoming connection.
    ///
    /// - Returns: `true` only if the peer is trusted.
    private func isTrustedClient( _ connection: NSXPCConnection ) -> Bool
    {
        #if canImport( Security )

        guard let token  = UpdaterServiceListenerDelegate.auditToken( of: connection ),
              let teamID = try? SecurityCodeSignatureInspector().runningApplicationIdentity().teamIdentifier
        else
        {
            return false
        }

        return XPCClientVerifier( teamIdentifier: teamID ).isValidClient( auditToken: token )

        #else

        return false

        #endif
    }

    #if canImport( Security )

    /// Reads a connection's peer audit token.
    ///
    /// `NSXPCConnection.auditToken` is SPI (absent from the public header), read here
    /// via key-value coding. It names the exact peer process, so verification is not
    /// vulnerable to the PID being reused by another process after the connection is
    /// made.
    ///
    /// - Parameter connection: The connection to read.
    ///
    /// - Returns: The peer's audit token, or `nil` if it cannot be read.
    private static func auditToken( of connection: NSXPCConnection ) -> audit_token_t?
    {
        guard let value = connection.value( forKey: "auditToken" ) as? NSValue
        else
        {
            return nil
        }

        var token = audit_token_t()

        value.getValue( &token, size: MemoryLayout< audit_token_t >.size )

        return token
    }

    #endif
}
