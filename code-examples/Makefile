# Preprocessing pipeline demo scripts - Makefile.
# Written by Christopher Thomas.

MATLAB=matlab
MATFLAGS=-nodisplay -nodesktop -nosplash
MATGUIFLAGS=-nodesktop -nosplash

default:
	@echo "Targets:   session preproc epoch gallery plotclean allclean"


plotclean:
	rm -f plots/*

allclean: plotclean
	rm -f data-sessions/*
	rm -rf data-trials/*
	rm -f data-epoched/*

checkdirs:
	./checkdirs.sh


session: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_sessionmeta.m'); exit;"

preproc: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_preproc.m'); exit;"

epoch: checkdirs
	nice -n +10 $(MATLAB) $(MATFLAGS) \
		-r "dbstop if error; run('do_epoch.m'); exit;"


gallery: gallery6

gallery3:
	sync
	cd plots; makegallery.pl --width=33% --nofolders *png; cd ..

gallery4:
	sync
	cd plots; makegallery.pl --width=24% --nofolders *png; cd ..

gallery6:
	sync
	cd plots; makegallery.pl --width=16% --nofolders *png; cd ..

#
# This is the end of the file.
