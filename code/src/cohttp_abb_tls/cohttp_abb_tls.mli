(** TLS connector for {!Cohttp_abb}. Use it when the client must fetch [https] URIs. It keeps the
    TLS dependency, and its static linking constraints, out of {!Cohttp_abb} itself. *)

module Make (Abb : Abb_intf.S with type Native.t = Unix.file_descr) : sig
  (** A connector that runs [https] requests over TLS. It uses [http/1.1] as the ALPN protocol and
      reads [CERTS_DIR], [NO_VERIFY_TLS_CERT], [NO_VERIFY_TLS_NAME] and the proxy-related
      environment variables. *)
  val connector : unit -> Cohttp_abb.Make(Abb).Client.Connector.t
end
