#require "jupyter-archimedes" ;;

let vp = A.init ~w:100. ~h:100. ["jupyter"] in
A.Axes.box vp ;
A.fx vp sin 0.0 10.0 ;
A.close vp ;;
