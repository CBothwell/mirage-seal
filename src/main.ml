(*
 * Copyright (c) 2015 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Cmdliner

let (/) = Filename.concat

let err fmt = Printf.ksprintf failwith fmt
let cmd fmt =
  Printf.ksprintf (fun str ->
      let i = Sys.command str in
      if i <> 0 then err "%s: failed with exit code %d." str i
    ) fmt

let verbose =
  let doc = Arg.info ~doc:"Be more verbose." ["v";"verbose"] in
  Arg.(value & flag & doc)

let color =
  let color_tri_state =
    try match Sys.getenv "COLOR" with
      | "always" -> `Always
      | "never"  -> `Never
      | _        -> `Auto
    with
    | Not_found  -> `Auto
  in
  let doc = Arg.info ~docv:"WHEN"
      ~doc:"Colorize the output. $(docv) must be `always', `never' or `auto'."
      ["color"]
  in
  let choices = Arg.enum [ "always", `Always; "never", `Never; "auto", `Auto ] in
  let arg = Arg.(value & opt choices color_tri_state & doc) in
  let to_bool = function
    | `Always -> true
    | `Never  -> false
    | `Auto   -> Unix.isatty Unix.stdout in
  Term.(pure to_bool $ arg)

let data =
  let doc = Arg.info ~docv:"DIR" ["d"; "data"]
      ~doc:"Location of the local directory containing the data to seal."
  in
  Arg.(required & opt (some string) None & doc)

let keys =
  let doc = Arg.info ~docv:"DIR" ["k";"keys"]
      ~doc:"Location of the private keys (server.pem and server.key) to sign \
            the sealing."
  in
  Arg.(required & opt (some string) None & doc)

let output_static ~dir name =
  match Static.read name with
  | None   -> err "%s: file not found" name
  | Some f ->
    let oc = open_out (dir / name) in
    output_string oc f;
    close_out oc

let copy ~dst src =
  if Sys.file_exists dst && Sys.is_directory dst then
    cmd "cp %s %s" src dst
  else
    err "copy: %s is not a valid directory" dst

(* FIXME: proper real-path *)
let realpath dir =
  if Filename.is_relative dir then Sys.getcwd () / dir else dir

let rmdir dir = cmd "rm -rf %s" dir
let mkdir dir = cmd "mkdir %s" dir

let seal verbose color seal_data seal_keys =
  if color then Log.color_on ();
  if verbose then Log.set_log_level Log.DEBUG;
  let exec_dir = Filename.get_temp_dir_name () / "mirage-seal" in
  rmdir exec_dir;
  mkdir exec_dir;
  mkdir (exec_dir / "keys");
  Printf.printf "exec-dir: %s\n%!" exec_dir;
  let seal_data = realpath seal_data in
  output_static ~dir:exec_dir "dispatch.ml";
  output_static ~dir:exec_dir "config.ml";
  copy (seal_keys / "server.pem") ~dst:(exec_dir / "keys");
  copy (seal_keys / "server.key") ~dst:(exec_dir / "keys");
  cmd "cd %s && SEAL_DATA=%s SEAL_KEYS=%s mirage configure"
    exec_dir seal_data (exec_dir / "keys");
  cmd "cd %s && make" exec_dir;
  copy (exec_dir / "seal.xe") ~dst:(Sys.getcwd ());
  if not (Sys.file_exists "seal.xl") then
    output_static ~dir:(Sys.getcwd ()) "seal.xl"

let cmd =
  let doc = "Seal a local directory into a Mirage unikernel." in
  let man = [
    `S "AUTHORS";
    `P "Thomas Gazagnaire   <thomas@gazagnaire.org>";

    `S "BUGS";
    `P "Check bug reports at https://github.com/samoht/mirage-seal/issues.";
  ] in
  Term.(pure seal $ verbose $ color $ data $ keys),
  Term.info "mirage-seal" ~version:Version.current ~doc ~man

let () = match Term.eval cmd with `Error _ -> exit 1 | _ -> exit 0
