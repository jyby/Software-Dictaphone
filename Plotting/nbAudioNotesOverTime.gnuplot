set title "History of the size of inboxes"
set style data lines
set xlabel "Dates"
set ylabel "Number of AudioNotes left to process"
set yrange [0:]
plot '~/AudioNotesToProcess/log' using 1:2:xticlabels(4) title "Nb AudioNotes"
