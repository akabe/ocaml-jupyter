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

open Format
open OUnit2
open Jupyter_notebook.Bench

let test__time ctxt =
  let actual_val, actual_time = time (fun () -> 2. ** 1000.) in
  let expected_val = 1.07150860718626732e+301 in
  assert_equal ~ctxt ~printer:[%show: float] expected_val actual_val ;
  assert_equal ~msg:"real time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<)
    0.0 actual_time.b_rtime ;
  assert_equal ~msg:"user time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<)
    0.0 actual_time.b_utime ;
  assert_equal ~msg:"sys time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<=)
    0.0 actual_time.b_stime ;
  assert_equal ~msg:"real time probably is up to 5 sec"
    ~ctxt ~printer:[%show: float] ~cmp:(>)
    5.0 actual_time.b_rtime ;
  assert_equal ~msg:"real time > user time"
    ~ctxt ~printer:[%show: float] ~cmp:(>)
    actual_time.b_rtime actual_time.b_utime ;
  assert_equal ~msg:"real time > sys time"
    ~ctxt ~printer:[%show: float] ~cmp:(>)
    actual_time.b_rtime actual_time.b_stime

let test__timeit ctxt =
  let actual_time = timeit (fun () -> 2. ** 1000.) in
  assert_equal ~msg:"mean of real time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<) 0.0 actual_time.b_rtime.bs_mean ;
  assert_equal ~msg:"mean of user time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<) 0.0 actual_time.b_utime.bs_mean ;
  assert_equal ~msg:"mean of sys time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<=) 0.0 actual_time.b_stime.bs_mean ;
  assert_equal ~msg:"std dev of real time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<=) 0.0 actual_time.b_rtime.bs_std ;
  assert_equal ~msg:"std dev of user time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<=) 0.0 actual_time.b_utime.bs_std ;
  assert_equal ~msg:"std dev of sys time is positive"
    ~ctxt ~printer:[%show: float] ~cmp:(<=) 0.0 actual_time.b_stime.bs_std

let suite =
  "Bench" >::: [
    "time" >:: test__time;
    "timeit" >:: test__timeit;
  ]
