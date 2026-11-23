Unit MKTlsLib;       {the OpenSSL libraries, loaded when they are wanted: nothing is linked, so MK runs without them (without TLS)}

{$mode objfpc}{$H+}

{
     LoadTls finds libssl and libcrypto (version 3, 1.1, or the plain name) and the few functions that the FPC openssl unit does not have in a form that
     works with OpenSSL 3.  False when the libraries are not there: the program goes on without TLS.  Used by MKFtp (client) and MKTls (server).
}

Interface

Uses ctypes, DynLibs;

Const
  SSL_CTRL_SET_TLSEXT_HOSTNAME = 55;
  SSL_CTRL_SET_MIN_PROTO_VERSION = 123;
  TLS1_2_VERSION = $0303;
  SSL_VERIFY_PEER = 1;

Type
  TGetSession = function(S: Pointer): Pointer; cdecl;
  TSetSession = function(S, Sess: Pointer): cint; cdecl;
  TFreeSession = procedure(Sess: Pointer); cdecl;
  TPeerCert = function(S: Pointer): Pointer; cdecl;
  TFreeX509 = procedure(X: Pointer); cdecl;
  TTlsMethod = function: Pointer; cdecl;
  TCheckHost = function(Cert: Pointer; Name: PChar; Len: PtrUInt; Flags: cuint; Peer: PPChar): cint; cdecl;
  TCtxCtrl = function(Ctx: Pointer; Cmd: cint; Larg: clong; Parg: Pointer): clong; cdecl;

Var
  LibSsl, LibCrypto: TLibHandle;
  pGetSession: TGetSession;
  pSetSession: TSetSession;
  pFreeSession: TFreeSession;
  pCheckHost: TCheckHost;
  pTlsMethod: TTlsMethod;               {TLS_client_method}
  pTlsServerMethod: TTlsMethod;         {TLS_server_method}
  pPeerCert: TPeerCert;
  pFreeX509: TFreeX509;
  pCtxCtrl: TCtxCtrl;

function LoadTls: Boolean;


Implementation

Uses SysUtils, openssl;

Var
  Loaded: Boolean;


function LoadTls: Boolean;
  Const
    SslNames: array[0..2] of String = ('libssl.so.3', 'libssl.so.1.1', 'libssl.so');
    CrNames: array[0..2] of String = ('libcrypto.so.3', 'libcrypto.so.1.1', 'libcrypto.so');
  Var
    i: Integer;

  Begin
  If Loaded Then
    Begin
    LoadTls := True;
    Exit;
    End;
  LoadTls := False;
  If GetEnvironmentVariable('MK_TLS_NO_LIBS') <> '' Then
    Exit;                                {a way to try the program as if the libraries were not installed}
  If Not InitSSLInterface Then
    Exit;
  LibSsl := NilHandle;
  LibCrypto := NilHandle;
  For i := 0 To 2 Do
    If LibSsl = NilHandle Then
      LibSsl := LoadLibrary(SslNames[i]);
  For i := 0 To 2 Do
    If LibCrypto = NilHandle Then
      LibCrypto := LoadLibrary(CrNames[i]);
  If (LibSsl = NilHandle) Or (LibCrypto = NilHandle) Then
    Exit;
  pGetSession := TGetSession(GetProcedureAddress(LibSsl, 'SSL_get1_session'));
  pSetSession := TSetSession(GetProcedureAddress(LibSsl, 'SSL_set_session'));
  pFreeSession := TFreeSession(GetProcedureAddress(LibSsl, 'SSL_SESSION_free'));
  pPeerCert := TPeerCert(GetProcedureAddress(LibSsl, 'SSL_get1_peer_certificate'));      {OpenSSL 3}
  If Not Assigned(pPeerCert) Then
    pPeerCert := TPeerCert(GetProcedureAddress(LibSsl, 'SSL_get_peer_certificate'));    {1.1}
  pFreeX509 := TFreeX509(GetProcedureAddress(LibCrypto, 'X509_free'));
  pTlsMethod := TTlsMethod(GetProcedureAddress(LibSsl, 'TLS_client_method'));
  pTlsServerMethod := TTlsMethod(GetProcedureAddress(LibSsl, 'TLS_server_method'));
  pCtxCtrl := TCtxCtrl(GetProcedureAddress(LibSsl, 'SSL_CTX_ctrl'));
  pCheckHost := TCheckHost(GetProcedureAddress(LibCrypto, 'X509_check_host'));
  Loaded := True;
  LoadTls := True;
  End;




Initialization
  Loaded := False;
End.
