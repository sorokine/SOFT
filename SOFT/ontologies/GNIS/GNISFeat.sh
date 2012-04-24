soft2gv.pl \
  --tuples GNISFeat.csv \
  --tuples GNISFeat_counts.csv \
  --styles GNIS.dotsty \
  -o GNISFeat.gv GNISFeat.soft && \
  dot -Tpdf -o GNISFeat.pdf GNISFeat.gv

