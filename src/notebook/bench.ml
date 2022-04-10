(* ocaml-jupyter --- An OCaml kernel for Jupyter

   Copyright (c) 2017 Akinori ABE

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. *)

(** Benchmark functions *)

open Format

type 'a t =
  {
    b_rtime : 'a; (** Real time for the process *)
    b_utime : 'a; (** User time for the process *)
    b_stime : 'a; (** System time for the process *)
  }

type stat =
  {
    bs_mean : float; (** Mean of execution time of a run *)
    bs_std : float; (** Standard deviation of execution time of a run *)
  }

let pp pp_a ppf x =
  fprintf ppf
    "Jupyter_notebook.Bench.({@;<0 2>@[b_rtime = %a;@ b_utime = %a;@ b_stime = %a;@ @]})"
    pp_a x.b_rtime pp_a x.b_utime pp_a x.b_stime

let pp_timedelta ppf x =
  if x < 1e-6 then fprintf ppf "%.3f ns" (x *. 1e9)
  else if x < 1e-3 then fprintf ppf "%.3f us" (x *. 1e6)
  else if x < 1.0 then fprintf ppf "%.3f ms" (x *. 1e3)
  else if x < 60.0 then fprintf ppf "%.3f s" x
  else begin
    let x, d = Float.modf (x /. 86400.0) in
    let x, h = Float.modf (x *. 24.0) in
    let s, m = Float.modf (x *. 60.0) in
    if d > 0.0 then fprintf ppf "%.0f days " d ;
    fprintf ppf "%.0f:%02.0f:%02.0f" h m s
  end

let pp_float_t = pp pp_timedelta

let pp_stat ppf x =
  fprintf ppf "%a ± %a" pp_timedelta x.bs_mean pp_timedelta x.bs_std

let time f =
  let rt0 = Unix.gettimeofday () in
  let tt0 = Unix.times () in
  let y = f () in
  let rt1 = Unix.gettimeofday () in
  let tt1 = Unix.times () in
  let res = {
    b_rtime = rt1 -. rt0;
    b_utime = tt1.Unix.tms_utime -. tt0.Unix.tms_utime;
    b_stime = tt1.Unix.tms_stime -. tt0.Unix.tms_stime;
  } in
  (y, res)

let stat ~f xs =
  let n = float_of_int (List.length xs) in
  let mean = List.fold_left (fun acc x -> acc +. f x) 0.0 xs /. n in
  let var =
    List.fold_left
      (fun acc x -> let y = f x -. mean in acc +. y *. y)
      0.0 xs /. n in
  {
    bs_mean = mean;
    bs_std = sqrt var;
  }

let timeit
    ?(runs = 5)
    ?(loops_per_run = 1000000)
    ?(before_run = fun () -> ())
    ?(after_run = fun () -> ())
    f
  =
  let lpr = float_of_int loops_per_run in
  let loop () =
    before_run () ;
    let rt0 = Unix.gettimeofday () in
    let tt0 = Unix.times () in
    for _ = 1 to loops_per_run do
      ignore (f ()) ;
    done ;
    let rt1 = Unix.gettimeofday () in
    let tt1 = Unix.times () in
    after_run () ;
    {
      b_rtime = (rt1 -. rt0) /. lpr;
      b_utime = (tt1.Unix.tms_utime -. tt0.Unix.tms_utime) /. lpr;
      b_stime = (tt1.Unix.tms_stime -. tt0.Unix.tms_stime) /. lpr;
    }
  in
  let ts = List.init runs (fun _ -> loop ()) in
  {
    b_rtime = stat ~f:(fun t -> t.b_rtime) ts;
    b_utime = stat ~f:(fun t -> t.b_utime) ts;
    b_stime = stat ~f:(fun t -> t.b_stime) ts;
  }
