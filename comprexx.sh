#!/bin/bash
# comprexx.sh v 0.1
# Author: mzt 2016-07-21 ( madztyles @ gmail dot com )
# TODO: quality switches & ... & ... & ...
# If used wrongly, this script could destroy substantial parts
# of the universe, so be aware of that and caution please.

# Copyright (C) 2016 mzt
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program;  If not, see <http://www.gnu.org/licenses/>.

# ENTER THE MADNESS

E_FATAL=81
E_USER_BREAK=82

info()
  {
	# get working directory, if not specified then pwd
	while [[ ! -d $worx ]]; do
		read -rp "starting directory, provide full or relative \
path [default $PWD]: " worx
		[[ -z $worx ]] && worx=${worx:-$PWD}
	done

	# search for flac or wav files?
	while [[ $seek != "flac" && $seek != "wav" ]]; do
		read -rp "convert wav or flac files? [wav, flac]: " seek
	done

	# lame or ogg, that is the question
	while [[ $codec != "ogg" && $codec != "lame" ]]; do
		read -rp "ogg or lame codec: " codec
	done
	# cmx for convenient, consistent function call
	[[ $codec = "lame" ]] && cmx=lame_enc || cmx=ogg_enc

	# prompt for decission before individual directory compression?
	while [[ $ask != "y" && $ask != "n" ]]; do
		read -rp "prompt for decission before directory compression? [y, n]: " ask
	done

	# ISO compatibility switch
	if [[ $cmx = "lame_enc" ]]; then
		while [[ $ISO != "y" && $ISO != "n" ]]; do
			read -rp "enforce ISO compatibility [y, n, help]: " ISO
			[[ $ISO = "help" ]] && printf "\n\t\t\tISO compatibility enforcement:
			enforcement of 7680 bit limitation on total frame size.
			lower quality for high bitrate encodings, but might be
			of importance for hardware players.\n\n" # | sed 's/^[ ]*//'
			# have to find out why sed wont align it on the left side
			# if no \t provided
		done
	fi
	[[ $ISO = y ]] && ISO="--strictly-enforce-ISO" || unset ISO

	# remove lossless files after compression?
	while [[ $rmv != "y" && $rmv != "n" ]]; do
		read -rp "remove lossless files after compression? [y, n]: " rmv
	done
  }

# create index list and array, each list index into one array element.
# if index already present, continue that?
init()
  {
	index="${worx}/files.data"

	if [[ ! -f $index ]]; then
		printf "searching through files now, this could take a while.\n"
		eval find . -name '*.$seek' > $index
		OLD_IFS=$IFS
		while IFS='' read -r init || [[ -n "$init" ]]; do
			file[i]=$init
			((i++))
		done < $index
		IFS=$OLD_IFS
	elif [[ -f $index ]]; then
		printf "file index already exists in that directory.\n"
		while [[ $cont != "y" && $cont != "n" ]]; do
			read -rp "continue to work on that index? [y, n]: " cont
		done
		[[ $cont = "n" ]] && ( printf "exiting comprexx.sh\n" && exit $E_USER_BREAK )
		[[ $cont = "y" ]] &&  while IFS='' read -r init || [[ -n "$init" ]]; do
			file[i]=$init
			((i++))
		done < $index
	else
		exit $E_FATAL
	fi
  }

# using mediainfo here for extracting the tags.
# using cut --complement for the case of embedded colons in the string.
# sed for getting  rid of the leading whitespace
lame_enc()
  {
	lame -m j --nohist --replaygain-accurate -S -q0 -v -V0 -b320 -B320 $ISO \
    --tc "encoded with comprexx.sh by mzt on $(date +%Y-%m-%d)" --ignore-tag-errors \
    --tt "$(mediainfo "${cur_file}" | grep -i 'track\ name\ ' | \
		cut -d ':' -f 1 --complement | sed 's/^[ \t]*//')" \
    --ta "$(mediainfo "${cur_file}" | grep -i 'performer\ ' | \
		cut -d ':' -f 1 --complement | sed 's/^[ \t]*//')" \
    --tl "$(mediainfo "${cur_file}" | grep -i 'album\ ' | \
		cut -d ':' -f 1 --complement | sed 's/^[ \t]*//')" \
    --ty "$(mediainfo "${cur_file}" | grep -i 'recorded\ date\ ' | \
		cut -d ':' -f 1 --complement | sed 's/^[ \t]*//')" \
    --tn "$(mediainfo "${cur_file}" | grep -i 'position\ ' | \
		cut -d ':' -f 1 --complement | sed 's/^[ \t]*//')" \
    --tg "$(mediainfo "${cur_file}" | grep -i 'genre\ ' | \
		cut -d ':' -f 1 --complement | sed 's/^[ \t]*//')" \
	"${cur_file}"  "${cur_file%.*}.mp3"
  }

ogg_enc()
  {
	oggenc -Q -b 350 -q 10 -c INFO="encoded with comprexx.sh by mzt on $(date +%Y-%m-%d)" \
		"${cur_file}"
  }



trash()
  {
	printf "deleting uncompressed files now in\n%s\n" "${temp_path}"
	eval rm "${file_path}/*.flac" && printf "directory cleaned\n"
  }

main()
  {
	OLD_PWD=$PWD
	cd "$worx"

	file_count=${#file[@]}
	printf "found %d files\n" "$file_count"

	# needs to get exported as function so that /usr/bin/time can measure the
	# compression duration (time (1) doesen't work on functions the normal way)
	export -f $cmx

	for ((i=0; i < $file_count; i++))
	  {
		file_path="$(dirname "${file[i]}")"
		temp_path="$(dirname "${file[$(($i - 1))]}")"
		plus_path="$(dirname "${file[$(($i + 1))]}")"

		# compress directory contents, yes or no?
		if [[ $file_path != $temp_path && $ask = "y" ]]; then
			while [[ $comp_dir != "y" && $comp_dir != "n" ]]; do
				# the echo command substitution is just for a clean new line inside read
				read -p "-> $file_path <- $(echo $'\ncompress files in that directory? [y, n]: ')" comp_dir
			done
		elif [[ $ask = "n" ]]; then
			comp_dir="y"
		fi

		# tme stores the current file's compression time, tme_catch catches directory
		# conversion time (these are for the log files) and tme_all is for supplying at
		# the end the overall compression time. And in between all that complex time confusion,
		# of course some files get compressed also. if desired..
		if [[ $comp_dir = "y" ]]; then

			# need to store array index into variable since the lame_enc function gets
			# called in subshell and arrays can't get exported
			cur_file="${file[i]}"
			export cur_file

			# compress file and store execution time in seconds
			# grep to get rid of lame output, we just want the time
			tme=$(echo $cmx "$cur_file" | /usr/bin/time -f '%e' /bin/bash 2>&1)
			tme=$(echo $tme | grep -oE '[^ ]+$')
			# also accumulate overall and dir duration
			tme_all=$(echo "${tme_all:-0}+$tme" | bc -ql)
			tme_catch=$(echo "${tme_catch:-0}+$tme" | bc -ql)

			# following are log jobs.
			# print header line in a new log
			if [[ $file_path != $temp_path ]]; then
				printf "%s - comprexx.sh mzt softworks\n\n" "${file_path##*/}" \
					> "${file_path}/${file_path##*/}".log
			fi
			# store individual track compression time
			printf "%s\nCompression time: %f\n\n" "${cur_file##*/}" "$tme" \
				>> "${file_path}/${file_path##*/}".log
			# log complete compression duration at end of log file
			if [[ $file_path != $plus_path ]]; then
				printf "\nComplete directory compression time in seconds: %f\n" "$tme_catch" \
					>> "${file_path}/${file_path##*/}".log
				unset tme_catch
			fi

			# finally trash that large crap.. space is valuable commodity these days, isn't it?
			[[ $file_path != $plus_path && $rmv = "y" ]] && trash

			# ready to get decission prompt for next iteration?
			[[ $file_path != $plus_path ]] && unset comp_dir
		fi

		# remove first index from index file, for functioning continuation
		# after script abortion or alike
		tail -n +2 $index > ${index}.tmp && mv ${index}{.tmp,}

		# end the session
		if [[ $i = $(($file_count - 1)) ]]; then
			printf "all work done\nno errors\ncomplete compression time: %.2f minutes\n\n" \
				"$(echo "scale=2; $tme_all/60" | bc -ql)"
			rm $index
			cd $OLD_PWD
		fi

	  # end of for loop body
	  }
  }

# sequentially call functions
info
init
main

exit 0
