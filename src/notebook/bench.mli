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

(** {2 Types} *)

(** The type of execution time of functions or code snippets.

    ['a] is [float] or [stat].

    @since 2.8.0 *)
type 'a t =
  {
    b_rtime : 'a; (** Real time for the process *)
    b_utime : 'a; (** User time for the process *)
    b_stime : 'a; (** System time for the process *)
  }

(** The type of summary results of repeated measurement of execution time.

    @since 2.8.0 *)
type stat =
  {
    bs_mean : float; (** Mean of execution time per a loop *)
    bs_std : float; (** Standard deviation of execution time per a loop *)
  }

(** {2 Benchmark} *)

(** [time f] measures execution time of a function [f].

    @return a pair of [f ()] and a result of benchmark.
    @since 2.8.0 *)
val time : (unit -> 'a) -> ('a * float t)

(** [timeit ?runs ?loops_per_run ?before_run ?after_run f]
    repeatedly executes a function [f], and measures the mean and
    the standard deviation of each execution time of [f ()].

    {[for i = 1 to runs do
        before_run () ;
        (* --- start measurement of execution time of each run --- *)
        for _ = 1 to loops_per_run do
          ignore (f ()) ;
        done ;
        (* --- finish measurement --- *)
        after_run () ;
      done]}

    [timeit] is inspired by {{:https://docs.python.org/3/library/timeit.html}timeit}
    package in Python. The parameter [loops_per_run], [before_run] are named as
    [number], [setup] respectively in Python.

    @param runs  the number of running (default = 5)
    @param loops_per_run  the number of loops per each run (default = 1,000,000)
    @param before_run  function once called before each run.
    @param after_run  function once called after each run.
    @return  summary of measurement.
    @since 2.8.0  *)
val timeit :
  ?runs:int ->
  ?loops_per_run:int ->
  ?before_run:(unit -> unit) ->
  ?after_run:(unit -> unit) ->
  (unit -> 'a) -> stat t

(** {2 Pretty printers} *)

(** @since 2.8.0 *)
val pp :
  (Format.formatter -> 'a -> unit) ->
  Format.formatter -> 'a t -> unit

(** @since 2.8.0 *)
val pp_float_t : Format.formatter -> float t -> unit

(** @since 2.8.0 *)
val pp_timedelta : Format.formatter -> float -> unit

(** @since 2.8.0 *)
val pp_stat : Format.formatter -> stat -> unit
