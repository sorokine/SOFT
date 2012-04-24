soft2gv.pl  --noorphans --sect-color=random --sect-outline\
  --tuples ElementList.csv,IsotopeList.csv,MoleculeList.csv \
  --styles ElementList.gvsty,IsotopeList.gvsty,MoleculeList.gvsty \
  --gvopts='rankdir=BT;dpi=72' --output=physics.gv \
  physics.soft && \
  dot -Tpdf -o physics.pdf physics.gv
