#!/bin/bash -eu

kernel_name=$1
dir=$(dirname $0)
exit_code=0

export LWT_LOG='* -> debug'

if ! [[ -f "$HOME/.ocamlinit" ]]; then
	cat <<'EOF' > "$HOME/.ocamlinit"
#use "topfind" ;;
EOF
fi

for name in $(ls $dir | grep '\.ipynb' | grep -o '^[^\.]*'); do
	tmpl_path="$dir/$name.ipynb"
	nb_path="$dir/$name.generated.ipynb"
	nbc_path="$dir/$name.nbconvert.ipynb"

	echo -e "\e[33mExecuting $nb_path...\033[0m"
	sed "s/__OCAML_KERNEL__/$kernel_name/" "$tmpl_path" > "$nb_path"
	if jupyter nbconvert --to notebook --execute "$nb_path"; then
		echo -e "\e[32m[Passed]\e[0m $name is OK."
	else
		echo -e "\e[31m[Failed]\e[0m $name is failed."
		exit_code=1
	fi

	rm -f "$nb_path" "$nbc_path"
done

exit $exit_code
