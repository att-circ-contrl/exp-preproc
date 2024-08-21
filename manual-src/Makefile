# Preprocessing pipeline libraries - Documentation - Makefile
# Written by Christopher Thomas.

REFNAME=exp-preproc-libraries
REFBASE=epp-libs


REFBITS=\
	$(REFNAME).tex			\
	$(REFBASE)-over.tex

REFAUTO=\
	$(REFBASE)-sample-preproc.tex	\
	$(REFBASE)-iter-notes.tex	\
	$(REFBASE)-iter.tex


default: force

libref: $(REFNAME).pdf
	cp $(REFNAME).pdf ../manuals

force: clean libref
	make autoclean

clean: tclean autoclean
	rm -f $(REFNAME).pdf

autoclean:
	rm -f $(REFAUTO)

tclean:
	rm -f $(REFNAME)*.log $(REFNAME)*.aux $(REFNAME)*.toc
	rm -f texput.*


refauto-bits: refauto-code refauto-notes refauto-examples

refauto-code:
	./copy-code.pl --outfile=$(REFBASE)-iter.tex --matlabdoc \
		"--chapter=\`\`epIter'' Functions" --label=sect-iter \
		../libraries/lib-exppreproc-iter/*m

refauto-notes:
	./copy-code.pl --outfile=$(REFBASE)-iter-notes.tex --verbatim \
		"--chapter=\`\`epIter'' Notes" --label=sect-iter-notes \
		../libraries/lib-exppreproc-iter/*txt

refauto-examples:
	./copy-code.pl --outfile=$(REFBASE)-sample-preproc.tex --verbatim \
		"--chapter=Preprocessing Example Script" \
		--label=sect-sample-preproc \
		../code-examples/*m

# FIXME - Additional information if I have multiple folders and README files.
#		"--chapter=\`\`ft-demo'' Example Script" \
#		../ft-demo/README.md ../ft-demo/*m

$(REFNAME).pdf: $(REFBITS) refauto-bits
	pdflatex $(REFNAME).tex
	pdflatex $(REFNAME).tex
	make tclean

#
# This is the end of the file.
