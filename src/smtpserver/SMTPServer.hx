package smtpserver;

import js.Error;
import js.node.Tls;
import js.node.net.Server;
import js.node.events.EventEmitter;
import js.node.stream.Readable;
import haxe.extern.EitherType;

typedef SMTPServerAddress = {
    /**
     * the address provided with the MAIL FROM or RCPT TO command
     */
    var address: String;
    /**
     * an object with additional arguments (all key names are uppercase)
     */
    var args: Dynamic;
}

enum abstract SMTPAuthenticationMethod(String) {
	var PLAIN = 'PLAIN';
	var LOGIN = 'LOGIN';
	var XOAUTH2 = 'XOAUTH2';
}

typedef SMTPServerAuthentication = {
    /**
     * indicates the authentication method used, 'PLAIN', 'LOGIN' or 'XOAUTH2'
     */
    var method: SMTPAuthenticationMethod;
    /**
     * the username of the user
     */
    var ?username: String;
    /**
     * the password if LOGIN or PLAIN was used
     */
    var ?password: String;
    /**
     *  the OAuth2 bearer access token if 'XOAUTH2' was used as the authentication method
     */
    var ?accessToken: String;
    /**
     * a function for validating CRAM-MD5 challenge responses.
     * Takes the password of the user as an argument and returns true if the response matches the password
     */
		var validatePassword: (password: String) -> Bool;
}

typedef SMTPServerAuthenticationResponse = {
    /**
     * can be any value - if this is set then the user is considered logged in
     * and this value is used later with the session data to identify the user.
     * If this value is empty, then the authentication is considered failed
     */
    var user: Dynamic;
    /**
     * an object to return if XOAUTH2 authentication failed (do not set the error object in this case).
     * This value is serialized to JSON and base64 encoded automatically, so you can just return the object
     */
    var ?data: Dynamic;
}

typedef SMTPServerSession = {
    /**
     * random string identificator generated when the client connected
     */
    var id: String;
    /**
     * local IP address for the connected client
     */
    var localAddress: String;
    /**
     * local port number for the connected client
     */
    var localPort: Int;
    /**
     * remote IP address for the connected client
     */
    var remoteAddress: String;
    /**
     * remote port number for the connected client
     */
    var remotePort: Int;
    /**
     * reverse resolved hostname for remoteAddress
     */
    var clientHostname: String;
    /**
     * the opening SMTP command (HELO/EHLO/LHLO)
     */
    var openingCommand: String;
    /**
     * hostname the client provided with HELO/EHLO call
     */
    var hostNameAppearsAs: String;
    /**
     * Envelope Object
     */
    var envelope: SMTPServerEnvelope;
    /**
     *  If true, then the connection is using TLS
     */
    var secure: Bool;

    var transmissionType: String;

    var tlsOptions: TlsCreateServerOptions;
}

typedef SMTPServerEnvelope = {
    /**
     * includes an address object or is set to false
     */
    var mailFrom: EitherType<SMTPServerAddress, Bool>;
    /**
     * includes an array of address objects
     */
    var rcptTo: Array<SMTPServerAddress>;
}

typedef SMTPServerOptions = TlsCreateServerOptions & {
    /**
     * if true, the connection will use TLS. The default is false.
     * If the server doesn't start in TLS mode,
     * it is still possible to upgrade clear text socket to
     * TLS socket with the STARTTLS command (unless you disable support for it).
     * If secure is true, additional tls options for tls.
     * createServer can be added directly onto this options object.
     */
    var ?secure: Bool;
    /** indicate an TLS server where TLS is handled upstream */
    var ?secured: Bool;
    /**
     * optional hostname of the server,
     * used for identifying to the client (defaults to os.hostname())
     */
    var ?name: String;
    /**
     * optional greeting message.
     * This message is appended to the default ESMTP response.
     */
    var ?banner: String;
    /**
     * optional maximum allowed message size in bytes
     * ([see details](https://github.com/andris9/smtp-server#using-size-extension))
     */
    var ?size: Int;
    /**
     * optional array of allowed authentication methods, defaults to ['PLAIN', 'LOGIN'].
     * Only the methods listed in this array are allowed,
     * so if you set it to ['XOAUTH2'] then PLAIN and LOGIN are not available.
     * Use ['PLAIN', 'LOGIN', 'XOAUTH2'] to allow all three.
     * Authentication is only allowed in secure mode
     * (either the server is started with secure: true option or STARTTLS command is used)
     */
    var ?authMethods: Array<String>;
    /**
     * allow authentication, but do not require it
     */
    var ?authOptional: Bool;
    /**
     * optional array of disabled commands (see all supported commands here).
     * For example if you want to disable authentication,
     * use ['AUTH'] as this value.
     * If you want to allow authentication in clear text, set it to ['STARTTLS'].
     */
    var ?disabledCommands: Array<String>; // TODO: ('AUTH' | 'STARTTLS' | 'XCLIENT' | 'XFORWARD')[];
    /**
     * optional boolean, if set to true then allow using STARTTLS
     * but do not advertise or require it. It only makes sense
     * when creating integration test servers for testing the scenario
     * where you want to try STARTTLS even when it is not advertised
     */
    var ?hideSTARTTLS: Bool;
    /**
     * optional boolean, if set to true then does not show PIPELINING in feature list
     */
    var ?hidePIPELINING: Bool;
    /**
     * optional boolean, if set to true then does not show 8BITMIME in features list
     */
    var ?hide8BITMIME: Bool;
    /**
     * optional boolean, if set to true then does not show SMTPUTF8 in features list
     */
    var ?hideSMTPUTF8: Bool;
    /**
     * optional boolean, if set to true allows authentication even if connection is not secured first
     */
    var ?allowInsecureAuth: Bool;
    /**
     * optional boolean, if set to true then does not try to reverse resolve client hostname
     */
    var ?disableReverseLookup: Bool;
    /**
     * optional Map or an object of TLS options for SNI where servername is the key. Overrided by SNICallback.
     */
    var ?sniOptions: Dynamic;
    /**
     * optional boolean, if set to true then upgrade sockets to TLS immediately after connection is established. Works with secure: true
     */
    var ?needsUpgrade: Bool;
    /**
     * optional bunyan compatible logger instance.
     * If set to true then logs to console.
     * If value is not set or is false then nothing is logged
     */
    var ?logger: Dynamic;
    /**
     * sets the maximum number of concurrently connected clients, defaults to Infinity
     */
    var ?maxClients: Int;
    /**
     * boolean, if set to true expects to be behind a proxy that emits a
     * [PROXY](http://www.haproxy.org/download/1.5/doc/proxy-protocol.txt) header (version 1 only)
     */
    var ?useProxy: Bool;
    /**
     * boolean, if set to true, enables usage of
     * [XCLIENT](http://www.postfix.org/XCLIENT_README.html) extension to override connection properties.
     * See session.xClient (Map object) for the details provided by the client
     */
    var ?useXClient: Bool;
    /**
     * boolean, if set to true, enables usage of [XFORWARD](http://www.postfix.org/XFORWARD_README.html) extension.
     * See session.xForward (Map object) for the details provided by the client
     */
    var ?useXForward: Bool;
    /**
     * boolean, if set to true use LMTP protocol instead of SMTP
     */
    var ?lmtp: Bool;
    /**
     * How many milliseconds of inactivity to allow before disconnecting the client (defaults to 1 minute)
     */
    var ?socketTimeout: Int;
    /**
     * How many millisceonds to wait before disconnecting pending
     * connections once `server.close()` has been called (defaults to 30 seconds)
     */
    var ?closeTimeout: Int;
    /**
     * The callback to handle authentications ([see details](https://github.com/andris9/smtp-server#handling-authentication))
     */
    var ?onAuth: (auth: SMTPServerAuthentication, session: SMTPServerSession, callback: (?err: Error, ?response: SMTPServerAuthenticationResponse) -> Void) -> Void;
    /**
     * The callback to handle the client connection. ([see details](https://github.com/andris9/smtp-server#validating-client-connection))
     */
    var ?onConnect: (session: SMTPServerSession, callback: (?err: Error) -> Void) -> Void;
    /**
     * the callback to validate MAIL FROM commands ([see details](https://github.com/andris9/smtp-server#validating-sender-addresses))
     */
    var ?onMailFrom: (address: SMTPServerAddress, session: SMTPServerSession, callback: (?err: Error) -> Void) -> Void;
    /**
     * The callback to validate RCPT TO commands ([see details](https://github.com/andris9/smtp-server#validating-recipient-addresses))
     */
    var ?onRcptTo: (address: SMTPServerAddress, session: SMTPServerSession, callback: (?err: Error) -> Void) -> Void;
    /**
     * the callback to handle incoming messages ([see details](https://github.com/andris9/smtp-server#processing-incoming-message))
     */
    var ?onData: (stream: Readable<String>, session: SMTPServerSession, callback: (?err: Error) -> Void) -> Void;
    /**
     * the callback that informs about closed client connection
     */
    var ?onClose: (session: SMTPServerSession, callback: (?err: Error) -> Void) -> Void;
}

@:jsRequire('smtp-server', 'SMTPServer')
extern class SMTPServer extends EventEmitter<SMTPServer> {
    var options: SMTPServerOptions;
    var logger: Dynamic;
    var secureContext: js.Map<String, js.node.tls.SecureContext>;
    var connections: js.Set<Dynamic>;
    var server: Server;

    function new(?options: SMTPServerOptions);

    /** Start listening on selected port and interface */
    @:overload(function (?port: Int, ?hostname: String, ?backlog: Int, ?listeningListener: () -> Void): Server {})
    @:overload(function (?port: Int, ?hostname: String, ?listeningListener: () -> Void): Server {})
    @:overload(function (?port: Int, ?backlog: Int, ?listeningListener: () -> Void): Server {})
    @:overload(function (?port: Int, ?listeningListener: () -> Void): Server {})
    @:overload(function (path: String, ?backlog: Int, ?listeningListener: () -> Void): Server {})
    @:overload(function (path: String, ?listeningListener: () -> Void): Void {})
    @:overload(function (options: EitherType<ServerListenOptionsTcp, ServerListenOptionsUnix>, ?listeningListener: () -> Void): Server {})
    @:overload(function (handle: Dynamic, ?backlog: Int, ?listeningListener: () -> Void): Server {})
    function listen(handle: Dynamic, ?listeningListener: () -> Void): Server;

    /** Closes the server */
    function close(callback: () -> Void): Void;

    function updateSecureContext(options: TlsCreateServerOptions): Void;

    /** Authentication handler. Override this */
    dynamic function onAuth(auth: SMTPServerAuthentication, session: SMTPServerSession, callback: (?err: Error, ?response: SMTPServerAuthenticationResponse) -> Void): Void;
    /** Override this */
    dynamic function onClose(session: SMTPServerSession, callback: (?err: Error) -> Void): Void;
    /** Override this */
    dynamic function onConnect(session: SMTPServerSession, callback: (?err: Error) -> Void): Void;
    /** Override this */
    dynamic function onData(stream: Readable<String>, session: SMTPServerSession, callback: (?err: Error) -> Void): Void;
    /** Override this */
    dynamic function onMailFrom(address: SMTPServerAddress, session: SMTPServerSession, callback: (?err: Error) -> Void): Void;
    /** Override this */
    dynamic function onRcptTo(address: SMTPServerAddress, session: SMTPServerSession, callback: (?err: Error) -> Void): Void;
}